import Foundation
import AppKit

@Observable
class AppState {
    enum Status: Equatable {
        case idle
        case selecting
        case adjusting
        case recording
        case finalizing
        case error(String)
    }

    private var isDisplayMetricsFrozen = false
    private var elapsedTimeStorage: TimeInterval = 0
    private var frameCountStorage: Int = 0
    private var skippedFrameCountStorage: Int = 0

    var status: Status = .idle {
        didSet {
            if case .finalizing = status {
                isDisplayMetricsFrozen = true
                return
            }

            if case .idle = status {
                resetDisplayMetrics()
            }
        }
    }
    var elapsedTime: TimeInterval {
        get { elapsedTimeStorage }
        set {
            guard !isDisplayMetricsFrozen else { return }
            elapsedTimeStorage = newValue
        }
    }
    var frameCount: Int {
        get { frameCountStorage }
        set {
            guard !isDisplayMetricsFrozen else { return }
            frameCountStorage = newValue
        }
    }
    var skippedFrameCount: Int {
        get { skippedFrameCountStorage }
        set {
            guard !isDisplayMetricsFrozen else { return }
            skippedFrameCountStorage = newValue
        }
    }
    var selectedRegion: CGRect = .zero
    var selectedScreen: NSScreen?
    var lastSaveFolder: URL?

    var isRecording: Bool { status == .recording }

    func resetDisplayMetrics() {
        isDisplayMetricsFrozen = false
        clearDisplayMetrics()
    }

    func reset() {
        status = .idle
        selectedRegion = .zero
        selectedScreen = nil
    }

    private func clearDisplayMetrics() {
        elapsedTimeStorage = 0
        frameCountStorage = 0
        skippedFrameCountStorage = 0
    }
}
