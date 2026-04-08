import Foundation
import AppKit

enum ControlPanelPhase: Equatable {
    case adjusting
    case recording
    case finalizing
}

struct ControlPanelViewState: Equatable {
    static let finalizingDotOpacity = 0.45
    static let actionButtonMinWidth: CGFloat = 80

    let showsAdjustingChips: Bool
    let showsRecordingStatus: Bool
    let isCloseEnabled: Bool
    let isActionEnabled: Bool
    let showsActionSpinner: Bool
    let actionTitle: String?
    let actionMinWidth: CGFloat
    let isRecordingDotPulsing: Bool
    let recordingDotOpacity: Double

    static func make(for phase: ControlPanelPhase) -> Self {
        switch phase {
        case .adjusting:
            ControlPanelViewState(
                showsAdjustingChips: true,
                showsRecordingStatus: false,
                isCloseEnabled: true,
                isActionEnabled: true,
                showsActionSpinner: false,
                actionTitle: String(localized: "Record"),
                actionMinWidth: actionButtonMinWidth,
                isRecordingDotPulsing: false,
                recordingDotOpacity: 1.0
            )
        case .recording:
            ControlPanelViewState(
                showsAdjustingChips: false,
                showsRecordingStatus: true,
                isCloseEnabled: true,
                isActionEnabled: true,
                showsActionSpinner: false,
                actionTitle: String(localized: "Stop"),
                actionMinWidth: actionButtonMinWidth,
                isRecordingDotPulsing: true,
                recordingDotOpacity: 1.0
            )
        case .finalizing:
            ControlPanelViewState(
                showsAdjustingChips: false,
                showsRecordingStatus: true,
                isCloseEnabled: false,
                isActionEnabled: false,
                showsActionSpinner: true,
                actionTitle: nil,
                actionMinWidth: actionButtonMinWidth,
                isRecordingDotPulsing: false,
                recordingDotOpacity: finalizingDotOpacity
            )
        }
    }
}

@Observable
final class ControlPanelContentModel {
    var phase: ControlPanelPhase
    var appState: AppState?

    var onRecord: () -> Void = {}
    var onStop: () -> Void = {}
    var onClose: () -> Void = {}

    init(phase: ControlPanelPhase, appState: AppState?) {
        self.phase = phase
        self.appState = appState
    }
}
