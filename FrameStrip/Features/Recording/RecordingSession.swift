import Foundation
import AppKit
import os

class RecordingSession {

    // MARK: - Testable Value Types

    struct AutoStopChecker: Sendable {
        let maxFrames: Int
        let maxDuration: Int

        func shouldStop(frameCount: Int, elapsed: TimeInterval) -> Bool {
            if maxFrames > 0 && frameCount >= maxFrames { return true }
            if maxDuration > 0 && elapsed >= Double(maxDuration) { return true }
            return false
        }
    }

    struct FailureTracker: Sendable {
        private(set) var consecutiveFailures = 0
        var shouldStop: Bool { consecutiveFailures >= 3 }

        mutating func recordFailure() { consecutiveFailures += 1 }
        mutating func recordSuccess() { consecutiveFailures = 0 }
    }

    enum StopReason: Equatable {
        case manual
        case autoStop
        case saveFailure(String)
        case displayChange
        case permissionRevoked
        case appTermination

        var userFacingErrorMessage: String? {
            switch self {
            case .manual, .autoStop, .appTermination:
                return nil
            case .saveFailure(let message):
                return message
            case .displayChange:
                return String(localized: "Recording stopped because display settings changed")
            case .permissionRevoked:
                return String(localized: "Screen recording permission was revoked")
            }
        }

        var shouldPresentCompletionPanel: Bool {
            self != .appTermination
        }
    }

    struct FinalizationResult {
        let info: CompletionInfo
        let errorMessage: String?
    }

    struct FinalizationTracker {
        enum Phase: Equatable {
            case recording
            case finalizing
            case finished
        }

        private(set) var phase: Phase = .recording
        private(set) var pendingSaves = 0
        private(set) var errorMessage: String?
        private var stopRequestSent = false

        var isRecording: Bool { phase == .recording }
        var isFinalizing: Bool { phase == .finalizing }

        mutating func reset() {
            phase = .recording
            pendingSaves = 0
            errorMessage = nil
            stopRequestSent = false
        }

        mutating func beginPendingSave() {
            guard phase == .recording else { return }
            pendingSaves += 1
        }

        mutating func shouldRequestStop(for reason: StopReason) -> Bool {
            guard phase == .recording, !stopRequestSent else { return false }
            stopRequestSent = true
            if case .saveFailure(let message) = reason {
                errorMessage = message
            }
            return true
        }

        mutating func beginFinalization(reason: StopReason) -> Bool {
            guard phase != .finished else { return false }
            if phase != .finalizing {
                phase = .finalizing
                if errorMessage == nil {
                    errorMessage = reason.userFacingErrorMessage
                }
            }
            return pendingSaves == 0
        }

        mutating func finishPendingSave(errorMessage: String? = nil) -> Bool {
            if let errorMessage {
                self.errorMessage = errorMessage
            }
            if pendingSaves > 0 {
                pendingSaves -= 1
            }
            return phase == .finalizing && pendingSaves == 0
        }

        mutating func markFinished() {
            phase = .finished
        }
    }

    // MARK: - Properties

    private let appState: AppState
    private let settings: SettingsManager
    private let captureManager: ScreenCaptureManager
    private let imageSaver: ImageSaver

    private var timer: Timer?
    private var startTime: Date?
    private var sessionDir: URL?
    private var autoStopChecker: AutoStopChecker?
    private var failureTracker = FailureTracker()
    private var displayChangeObserver: (any NSObjectProtocol)?

    private var changeDetector: ChangeDetector?
    private var savedFrameCount: Int = 0  // saveQueue에서만 접근
    private var completedFrameCount: Int = 0  // main thread에서만 접근
    private var completedSkippedFrameCount: Int = 0  // main thread에서만 접근
    private var finalizationTracker = FinalizationTracker()
    private var lastThumbnail: NSImage?

    private var interactionMonitor: InteractionMonitor?
    private var frameRecords: [SessionManifest.FrameRecord] = []  // saveQueue에서 mutate, drain 후 main에서 read
    private var lastCaptureTime: Date = .distantPast
    private let minEventInterval: TimeInterval = 0.05

    private let maxPendingSaves = 10
    private let reservedEventSlots = 2

    private var timerSaveLimit: Int {
        settings.interactionCapture ? maxPendingSaves - reservedEventSlots : maxPendingSaves
    }
    private let saveQueue = DispatchQueue(label: "com.ttings.FrameStrip.save", qos: .userInitiated)

    var onStopRequested: ((StopReason) -> Void)?
    var onFinalized: ((FinalizationResult) -> Void)?
    var onThumbnailUpdated: ((NSImage, Int) -> Void)?

    init(appState: AppState, settings: SettingsManager, captureManager: ScreenCaptureManager) {
        self.appState = appState
        self.settings = settings
        self.captureManager = captureManager
        self.imageSaver = ImageSaver(baseDirectory: settings.saveFolderURL)
    }

    // MARK: - Start / Stop

    func start(region: CGRect, screen: NSScreen) async throws {
        sessionDir = try imageSaver.createSessionFolder()

        appState.resetDisplayMetrics()
        appState.selectedRegion = region
        appState.selectedScreen = screen
        appState.lastSaveFolder = sessionDir

        startTime = Date()
        failureTracker = FailureTracker()
        finalizationTracker.reset()
        savedFrameCount = 0
        completedFrameCount = 0
        completedSkippedFrameCount = 0
        lastThumbnail = nil
        frameRecords = []
        lastCaptureTime = .distantPast
        if settings.changeDetectionEnabled {
            changeDetector = ChangeDetector(threshold: settings.changeDetectionThreshold)
        } else {
            changeDetector = nil
        }
        autoStopChecker = AutoStopChecker(
            maxFrames: settings.maxFrames,
            maxDuration: settings.maxDuration
        )

        try await captureManager.prepareForCapture(on: screen)

        observeDisplayChanges()

        let captureTimer = Timer(timeInterval: settings.captureInterval, repeats: true) { [weak self] _ in
            self?.captureFrame()
        }
        RunLoop.current.add(captureTimer, forMode: .common)
        timer = captureTimer
        captureFrame()

        if settings.interactionCapture {
            let monitor = InteractionMonitor()
            monitor.onInteraction = { [weak self] nsEvent in
                DispatchQueue.main.async {
                    self?.handleInteractionEvent(nsEvent)
                }
            }
            monitor.start()
            interactionMonitor = monitor
        }
    }

    func beginFinalization(reason: StopReason) {
        let shouldFinalizeNow = finalizationTracker.beginFinalization(reason: reason)

        timer?.invalidate()
        timer = nil
        interactionMonitor?.stop()
        interactionMonitor = nil
        captureManager.endCapture()
        changeDetector = nil
        removeDisplayChangeObserver()
        startTime = nil

        if shouldFinalizeNow {
            finalizeIfPossible()
        }
    }

    // MARK: - Capture Loop

    private func captureFrame(interactionEvent: InteractionEvent? = nil) {
        guard finalizationTracker.isRecording,
              let screen = appState.selectedScreen,
              let sessionDir else { return }

        let saveLimit = interactionEvent != nil ? maxPendingSaves : timerSaveLimit
        guard finalizationTracker.pendingSaves < saveLimit else {
            AppLogger.recording.warning("Save queue overflow (\(self.finalizationTracker.pendingSaves)/\(saveLimit)) — frame dropped")
            return
        }

        if let start = startTime {
            appState.elapsedTime = Date().timeIntervalSince(start)
        }

        if let checker = autoStopChecker,
           checker.shouldStop(frameCount: completedFrameCount, elapsed: appState.elapsedTime) {
            requestStopIfNeeded(.autoStop)
            return
        }

        let region = appState.selectedRegion
        let elapsed = appState.elapsedTime
        let format = settings.imageFormat
        let quality = settings.jpegQuality
        let saver = self.imageSaver
        let sessionDirCopy = sessionDir
        let detector = self.changeDetector
        let showsCursor = settings.showCursor

        lastCaptureTime = Date()
        finalizationTracker.beginPendingSave()

        Task {
            do {
                let image = try await captureManager.captureRegion(region, on: screen, showsCursor: showsCursor)

                saveQueue.async { [weak self] in
                    autoreleasepool {
                        if interactionEvent == nil, let detector, !detector.hasChanged(image) {
                            guard let self else { return }
                            DispatchQueue.main.async {
                                self.completedSkippedFrameCount += 1
                                if self.finalizationTracker.isRecording {
                                    self.appState.skippedFrameCount = self.completedSkippedFrameCount
                                }
                                self.finishPendingSave()
                            }
                            return
                        }

                        guard let self else { return }
                        self.savedFrameCount += 1
                        let frameNumber = self.savedFrameCount

                        do {
                            let savedURL = try saver.save(image: image, format: format, quality: quality, to: sessionDirCopy, frameNumber: frameNumber, elapsedTime: elapsed)
                            let filename = savedURL.lastPathComponent
                            self.frameRecords.append(SessionManifest.FrameRecord(
                                filename: filename,
                                time: elapsed,
                                event: interactionEvent
                            ))
                            let thumbnail = ThumbnailGenerator.generate(from: image)
                            let savedCount = self.savedFrameCount
                            DispatchQueue.main.async {
                                self.completedFrameCount = savedCount
                                self.lastThumbnail = thumbnail
                                if self.finalizationTracker.isRecording {
                                    self.appState.frameCount = self.completedFrameCount
                                    if let thumbnail {
                                        self.onThumbnailUpdated?(thumbnail, self.completedFrameCount)
                                    }
                                }
                                self.failureTracker.recordSuccess()
                                self.finishPendingSave()
                            }
                        } catch {
                            DispatchQueue.main.async {
                                self.handleSaveFailure(error)
                            }
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.handleSaveFailure(error)
                }
            }
        }
    }

    // MARK: - Interaction Events

    private func handleInteractionEvent(_ nsEvent: NSEvent) {
        guard finalizationTracker.isRecording,
              let screen = appState.selectedScreen else { return }

        let now = Date()
        guard now.timeIntervalSince(lastCaptureTime) >= minEventInterval else { return }

        let mouseLocation = NSEvent.mouseLocation
        let region = appState.selectedRegion
        let cgRegion = CoordinateUtils.cgToAppKitWindowFrame(region, on: screen)
        guard cgRegion.contains(mouseLocation) else { return }

        let relativeX = mouseLocation.x - cgRegion.origin.x
        let relativeAppKitY = mouseLocation.y - cgRegion.origin.y
        let relativeY = cgRegion.height - relativeAppKitY
        let pixelX = Int(max(0, min(relativeX, region.width - 1)))
        let pixelY = Int(max(0, min(relativeY, region.height - 1)))

        let eventType: InteractionEvent.EventType
        switch nsEvent.type {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            eventType = .mouseDown
        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            eventType = .mouseUp
        case .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            eventType = .dragStart
        default:
            return
        }

        let button: InteractionEvent.MouseButton
        switch nsEvent.buttonNumber {
        case 0: button = .left
        case 1: button = .right
        default: button = .other
        }

        var modifiers: [String] = []
        if nsEvent.modifierFlags.contains(.command) { modifiers.append("⌘") }
        if nsEvent.modifierFlags.contains(.shift) { modifiers.append("⇧") }
        if nsEvent.modifierFlags.contains(.option) { modifiers.append("⌥") }
        if nsEvent.modifierFlags.contains(.control) { modifiers.append("⌃") }

        let event = InteractionEvent(
            type: eventType,
            button: button,
            position: PixelPosition(x: pixelX, y: pixelY),
            modifiers: modifiers
        )

        captureFrame(interactionEvent: event)
    }

    // MARK: - Error Handling

    private func handleSaveFailure(_ error: Error) {
        let message = userFriendlyMessage(for: error)

        if finalizationTracker.phase == .finalizing {
            AppLogger.recording.error("Frame save failed during finalization: \(error)")
            finishPendingSave(errorMessage: message)
            return
        }

        if let captureError = error as? ScreenCaptureManager.CaptureError,
           captureError == .permissionDenied {
            AppLogger.recording.error("Screen recording permission revoked — stopping immediately")
            requestStopIfNeeded(.permissionRevoked)
            finishPendingSave()
            return
        }

        failureTracker.recordFailure()
        AppLogger.recording.error("Frame save failed (\(self.failureTracker.consecutiveFailures)/3): \(error)")

        if failureTracker.shouldStop {
            requestStopIfNeeded(.saveFailure(message))
        }

        finishPendingSave()
    }

    private func userFriendlyMessage(for error: Error) -> String {
        if let captureError = error as? ScreenCaptureManager.CaptureError {
            switch captureError {
            case .permissionDenied: return String(localized: "Screen recording permission was revoked")
            case .noDisplayFound: return String(localized: "Target display not found")
            case .captureFailed: return String(localized: "Screen capture failed")
            }
        }

        if error is ImageSaver.SaveError, let dir = sessionDir {
            if !FileManager.default.fileExists(atPath: dir.path) {
                return String(localized: "Save folder was deleted")
            }
            if !FileManager.default.isWritableFile(atPath: dir.path) {
                return String(localized: "No write permission for save folder")
            }
            if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: dir.path),
               let free = attrs[.systemFreeSize] as? Int64,
               free < 100_000_000 {
                return String(localized: "Not enough disk space")
            }
            return String(localized: "Failed to save image")
        }

        return String(localized: "Save failed: \(error.localizedDescription)")
    }

    // MARK: - Display Change Detection

    private func observeDisplayChanges() {
        displayChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            AppLogger.recording.warning("Display settings change detected — stopping recording")
            self?.requestStopIfNeeded(.displayChange)
        }
    }

    private func removeDisplayChangeObserver() {
        if let observer = displayChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            displayChangeObserver = nil
        }
    }

    private func requestStopIfNeeded(_ reason: StopReason) {
        guard finalizationTracker.shouldRequestStop(for: reason) else { return }
        onStopRequested?(reason)
    }

    private func finishPendingSave(errorMessage: String? = nil) {
        let shouldFinalize = finalizationTracker.finishPendingSave(errorMessage: errorMessage)
        if shouldFinalize {
            finalizeIfPossible()
        }
    }

    private func finalizeIfPossible() {
        guard finalizationTracker.phase == .finalizing,
              finalizationTracker.pendingSaves == 0 else { return }

        finalizationTracker.markFinished()

        let interactionEventCount = frameRecords.filter { $0.event != nil }.count

        if let sessionDir, completedFrameCount > 0 {
            let manifestSettings = SessionManifest.Settings(
                captureInterval: settings.captureInterval,
                imageFormat: settings.imageFormat.rawValue,
                changeDetection: settings.changeDetectionEnabled,
                changeThreshold: settings.changeDetectionThreshold,
                showCursor: settings.showCursor,
                interactionCapture: settings.interactionCapture
            )
            let segments = SessionManifest.buildSegments(from: frameRecords)
            let manifest = SessionManifest(
                settings: manifestSettings,
                duration: (appState.elapsedTime * 1000).rounded() / 1000,
                totalFrames: completedFrameCount,
                interactionEvents: interactionEventCount,
                segments: segments
            )
            do {
                try manifest.write(to: sessionDir)
            } catch {
                AppLogger.recording.error("Failed to write session.json: \(error)")
            }
        }

        if completedFrameCount == 0, let sessionDir {
            try? FileManager.default.removeItem(at: sessionDir)
            appState.lastSaveFolder = nil
        }

        let info = CompletionInfo(
            frameCount: completedFrameCount,
            skippedCount: completedSkippedFrameCount,
            interactionEventCount: interactionEventCount,
            folder: sessionDir,
            lastThumbnail: lastThumbnail,
            interval: settings.captureInterval,
            changeDetection: settings.changeDetectionEnabled,
            format: settings.imageFormat.rawValue.uppercased(),
            duration: appState.elapsedTime
        )
        let result = FinalizationResult(info: info, errorMessage: finalizationTracker.errorMessage)

        onFinalized?(result)
        onFinalized = nil
        onStopRequested = nil
    }

}
