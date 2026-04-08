import AppKit

class RecordingCoordinator {
    private static let menuUpdateInterval: TimeInterval = 1.0
    private static let errorClearDelay: TimeInterval = 5.0
    private static let overlayFadeInDuration: TimeInterval = 0.2
    private static let transitionDuration: TimeInterval = 0.2
    private static let transitionFrameCount = 12

    private let appState: AppState
    private let captureManager = ScreenCaptureManager()
    private let hotkeyManager = GlobalHotkeyManager()

    private var recordingSession: RecordingSession?
    private var selectionWindows: [RegionSelectionWindow] = []
    private var selectionEscLocalMonitor: Any?
    private var selectionEscGlobalMonitor: Any?
    private var screenChangeObserver: NSObjectProtocol?
    private var borderWindow: RecordingBorderWindow?
    private var controlPanel: SelectionControlPanel?
    private var floatingPanel: RegionFloatingPanel?

    private var menuUpdateTimer: Timer?
    private var recordingPanelEscLocalMonitor: Any?
    private var recordingPanelEscGlobalMonitor: Any?
    private var lastThumbnail: NSImage?
    private var stopReason: RecordingSession.StopReason?
    private var terminationRequested = false
    private var isTransitioningToRecording = false

    // MARK: - Callbacks

    var onRecordingStarted: (() -> Void)?
    var onFinalizingStarted: ((Int) -> Void)?
    var onRecordingStopped: (() -> Void)?
    var onRecordingCompleted: ((CompletionInfo) -> Void)?
    var onError: ((String) -> Void)?
    var onErrorCleared: (() -> Void)?
    var onPermissionGranted: (() -> Void)?
    var onPermissionDenied: (() -> Void)?
    var onStatusUpdate: ((TimeInterval, Double, Bool) -> Void)?
    var onThumbnailUpdated: ((NSImage, Int) -> Void)?
    var onTerminationReady: (() -> Void)?

    var isRecording: Bool { appState.isRecording }
    var isFinalizing: Bool { appState.status == .finalizing }

    init(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Hotkey

    func registerHotkey() {
        let settings = SettingsManager.shared
        hotkeyManager.register(
            keyCode: settings.hotkeyKeyCode,
            modifiers: settings.hotkeyModifiers
        ) { [weak self] in
            self?.handleHotkey()
        }
    }

    // MARK: - Hotkey Handler

    func handleHotkey() {
        switch appState.status {
        case .idle:
            startRegionSelection()
        case .selecting:
            break
        case .adjusting:
            confirmAndStartRecording()
        case .recording:
            showControlPanelInRecordingMode()
        case .finalizing:
            break
        case .error:
            break
        }
    }

    // MARK: - Event Monitor Helpers

    private func removeEventMonitor(_ monitor: inout Any?) {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
    }

    // MARK: - Region Selection

    func closeAllSelectionWindows() {
        cleanupSelectionOverlays()
        controlPanel?.close()
        isTransitioningToRecording = false

        if appState.status == .selecting || appState.status == .adjusting {
            appState.status = .idle
        }
    }

    /// 녹화 전환 시 오버레이만 정리 — 취소 시에는 closeAllSelectionWindows() 사용
    private func cleanupSelectionOverlays() {
        floatingPanel?.close()
        floatingPanel = nil

        for window in selectionWindows {
            window.close()
        }
        selectionWindows = []

        removeEventMonitor(&selectionEscLocalMonitor)
        removeEventMonitor(&selectionEscGlobalMonitor)

        if let observer = screenChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            screenChangeObserver = nil
        }
    }

    func startRegionSelection() {
        if !captureManager.hasPermission() {
            captureManager.requestPermission()
            onPermissionDenied?()
            return
        }
        onPermissionGranted?()

        guard appState.status == .idle else { return }

        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }

        appState.status = .selecting

        for screen in screens {
            let window = RegionSelectionWindow(
                screen: screen,
                onRegionReady: { [weak self] rect, selectedScreen in
                    self?.enterAdjustingMode(region: rect, screen: selectedScreen)
                },
                onCancel: { [weak self] in
                    self?.closeAllSelectionWindows()
                }
            )
            window.alphaValue = 0
            window.orderFront(nil)
            selectionWindows.append(window)
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.overlayFadeInDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            for window in selectionWindows {
                window.animator().alphaValue = 1
            }
        }

        NSApp.activate(ignoringOtherApps: true)

        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.closeAllSelectionWindows()
        }

        selectionEscLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == KeyCodes.escape {
                self?.closeAllSelectionWindows()
                return nil
            }
            return event
        }
        selectionEscGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == KeyCodes.escape {
                DispatchQueue.main.async { self?.closeAllSelectionWindows() }
            }
        }
    }

    // MARK: - Adjusting Mode

    private func enterAdjustingMode(region: CGRect, screen: NSScreen) {
        appState.status = .adjusting
        appState.selectedRegion = region
        appState.selectedScreen = screen

        for window in selectionWindows {
            window.resetToOverlay()
        }

        removeEventMonitor(&selectionEscLocalMonitor)
        removeEventMonitor(&selectionEscGlobalMonitor)

        // FloatingPanel이 key window를 잃어도 Esc로 취소 가능하도록 글로벌 모니터 등록
        selectionEscGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == KeyCodes.escape {
                DispatchQueue.main.async { self?.closeAllSelectionWindows() }
            }
        }

        let globalRegion = CoordinateUtils.cgToAppKitWindowFrame(region, on: screen)

        let panel = RegionFloatingPanel(globalRegion: globalRegion)
        panel.onRegionChanged = { [weak self] globalRect in
            self?.handleFloatingRegionChanged(globalRect)
        }
        panel.onEnterPressed = { [weak self] in
            self?.confirmAndStartRecording()
        }
        panel.onCancel = { [weak self] in
            self?.closeAllSelectionWindows()
        }
        panel.makeKeyAndOrderFront(nil)
        floatingPanel = panel

        handleFloatingRegionChanged(globalRegion)

        if controlPanel == nil {
            controlPanel = SelectionControlPanel(mode: .adjusting, below: region, on: screen)
            controlPanel?.onRecord = { [weak self] in self?.confirmAndStartRecording() }
            controlPanel?.onClose = { [weak self] in self?.closeAllSelectionWindows() }
        }
        controlPanel?.showWithFadeIn()
    }

    private func handleFloatingRegionChanged(_ globalRect: CGRect) {
        for window in selectionWindows {
            window.updateCutout(globalRect: globalRect)
        }

        let screens = NSScreen.screens
        let screenFrames = screens.map(\.frame)
        if let targetFrame = CoordinateUtils.screenForCenterPoint(globalRect, screenFrames: screenFrames),
           let targetScreen = screens.first(where: { $0.frame == targetFrame }) {
            let cgRegion = CoordinateUtils.globalAppKitToCG(globalRect, screenFrame: targetFrame)
            appState.selectedRegion = cgRegion
            appState.selectedScreen = targetScreen
        }
    }

    private func confirmAndStartRecording() {
        guard appState.status == .adjusting, !isTransitioningToRecording else { return }
        isTransitioningToRecording = true

        guard let panel = floatingPanel else { return }
        // handleFloatingRegionChanged()와 중복처럼 보이지만, clampToScreenCG()를 추가 적용하여
        // 모니터 경계를 넘어간 영역을 최종 클램핑한다. appState 값을 그대로 쓰면 안 됨.
        let globalRect = panel.globalRegionRect

        let screens = NSScreen.screens
        let screenFrames = screens.map(\.frame)
        guard let targetFrame = CoordinateUtils.screenForCenterPoint(globalRect, screenFrames: screenFrames),
              let screen = screens.first(where: { $0.frame == targetFrame }) else { return }

        var cgRegion = CoordinateUtils.globalAppKitToCG(globalRect, screenFrame: targetFrame)
        cgRegion = CoordinateUtils.clampToScreenCG(cgRegion, screenWidth: targetFrame.width, screenHeight: targetFrame.height)

        appState.selectedRegion = cgRegion
        appState.selectedScreen = screen

        controlPanel?.switchToRecordingMode(appState: appState)
        configureControlPanelForRecording()

        // NSAnimationContext는 커스텀 progress 콜백을 지원하지 않으므로
        // setTransitionProgress()에 0→1 값을 점진적으로 전달하려면 Timer가 필요
        var frameIndex = 0
        let totalFrames = Self.transitionFrameCount
        let interval = Self.transitionDuration / Double(totalFrames)

        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            frameIndex += 1
            let progress = CGFloat(frameIndex) / CGFloat(totalFrames)
            for window in self.selectionWindows {
                window.setTransitionProgress(progress)
            }
            if frameIndex >= totalFrames {
                timer.invalidate()
                self.cleanupSelectionOverlays()
                self.startRecording(region: cgRegion, screen: screen)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    // MARK: - Recording Mode Panel

    private func showControlPanelInRecordingMode() {
        guard appState.status == .recording else { return }

        if let panel = controlPanel, panel.isVisible { return }

        if controlPanel != nil {
            controlPanel?.switchToRecordingMode(appState: appState)
            controlPanel?.restoreAtLastPosition()
        } else if let screen = appState.selectedScreen {
            controlPanel = SelectionControlPanel(mode: .recording, below: appState.selectedRegion, on: screen, appState: appState)
            controlPanel?.showWithFadeIn()
        }

        configureControlPanelForRecording()
    }

    private func configureControlPanelForRecording() {
        controlPanel?.onStop = { [weak self] in self?.stopRecording() }
        controlPanel?.onClose = { [weak self] in
            self?.controlPanel?.close()
            self?.cleanupRecordingPanelEscMonitors()
        }
        setupRecordingPanelEscMonitors()
    }

    private func setupRecordingPanelEscMonitors() {
        cleanupRecordingPanelEscMonitors()

        recordingPanelEscLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == KeyCodes.escape {
                self?.controlPanel?.close()
                self?.cleanupRecordingPanelEscMonitors()
                return nil
            }
            return event
        }
        recordingPanelEscGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == KeyCodes.escape {
                DispatchQueue.main.async {
                    self?.controlPanel?.close()
                    self?.cleanupRecordingPanelEscMonitors()
                }
            }
        }
    }

    private func cleanupRecordingPanelEscMonitors() {
        removeEventMonitor(&recordingPanelEscLocalMonitor)
        removeEventMonitor(&recordingPanelEscGlobalMonitor)
    }

    // MARK: - Recording Start

    private func startRecording(region: CGRect, screen: NSScreen) {
        let session = RecordingSession(
            appState: appState,
            settings: SettingsManager.shared,
            captureManager: captureManager
        )
        do {
            session.onStopRequested = { [weak self] reason in
                self?.requestStop(reason: reason)
            }
            session.onFinalized = { [weak self] result in
                self?.finishFinalization(result)
            }
            session.onThumbnailUpdated = { [weak self] image, frameCount in
                self?.lastThumbnail = image
                self?.onThumbnailUpdated?(image, frameCount)
            }

            try session.start(region: region, screen: screen)
            recordingSession = session
            appState.status = .recording
            stopReason = nil
            terminationRequested = false
            isTransitioningToRecording = false

            onRecordingStarted?()

            borderWindow = RecordingBorderWindow(region: region, screen: screen)
            borderWindow?.orderFront(nil)
            borderWindow?.startPulsing()

            let updateTimer = Timer(timeInterval: Self.menuUpdateInterval, repeats: true) { [weak self] _ in
                guard let self else { return }
                self.onStatusUpdate?(self.appState.elapsedTime, SettingsManager.shared.captureInterval, SettingsManager.shared.changeDetectionEnabled)
            }
            RunLoop.current.add(updateTimer, forMode: .common)
            menuUpdateTimer = updateTimer
        } catch {
            isTransitioningToRecording = false
            controlPanel?.close()
            controlPanel = nil
            cleanupRecordingPanelEscMonitors()
            handleError(error.localizedDescription)
        }
    }

    // MARK: - Recording Stop

    func stopRecording() {
        requestStop(reason: .manual)
    }

    func requestApplicationTermination() {
        if appState.status == .finalizing {
            terminationRequested = true
            return
        }

        requestStop(reason: .appTermination)
    }

    func requestStop(reason: RecordingSession.StopReason) {
        if appState.status == .finalizing {
            if reason == .appTermination {
                terminationRequested = true
            }
            return
        }

        guard appState.status == .recording else { return }
        guard let session = recordingSession else { return }

        stopReason = reason
        if reason == .appTermination {
            terminationRequested = true
        }

        appState.status = .finalizing
        beginFinalizingUI()
        session.beginFinalization(reason: reason)
    }

    private func beginFinalizingUI() {
        stopRecordingChrome()

        if let controlPanel, controlPanel.isVisible {
            controlPanel.switchToFinalizingMode(appState: appState)
        }

        onFinalizingStarted?(appState.frameCount)
    }

    private func finishFinalization(_ result: RecordingSession.FinalizationResult) {
        let shouldTerminate = terminationRequested
        let shouldShowCompletion = result.info.frameCount > 0 && (stopReason?.shouldPresentCompletionPanel ?? true)
        let isPermissionRevoked = stopReason == .permissionRevoked

        completeFinalization(result, shouldTerminate: shouldTerminate, shouldShowCompletion: shouldShowCompletion, isPermissionRevoked: isPermissionRevoked)
    }

    private func completeFinalization(
        _ result: RecordingSession.FinalizationResult,
        shouldTerminate: Bool,
        shouldShowCompletion: Bool,
        isPermissionRevoked: Bool = false
    ) {
        recordingSession = nil
        stopReason = nil
        terminationRequested = false
        lastThumbnail = nil

        stopRecordingChrome()
        controlPanel?.close()
        controlPanel = nil

        appState.status = .idle
        onRecordingStopped?()

        if shouldShowCompletion {
            onRecordingCompleted?(result.info)
        }

        if shouldTerminate {
            onTerminationReady?()
            return
        }

        if let message = result.errorMessage {
            handleError(message, isPermissionError: isPermissionRevoked)
        } else if isPermissionRevoked {
            onPermissionDenied?()
        }
    }

    private func stopRecordingChrome() {
        cleanupRecordingPanelEscMonitors()

        menuUpdateTimer?.invalidate()
        menuUpdateTimer = nil

        borderWindow?.stopPulsing()
        borderWindow = nil
    }

    // MARK: - Error Handling

    private func handleError(_ message: String, isPermissionError: Bool = false) {
        appState.status = .error(message)
        onError?(message)

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.errorClearDelay) { [weak self] in
            guard let self else { return }
            if case .error = self.appState.status {
                self.appState.status = .idle
                self.onErrorCleared?()
                if isPermissionError {
                    self.onPermissionDenied?()
                }
            }
        }
    }
}
