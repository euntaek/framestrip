import Testing
import Foundation
import CoreGraphics
@testable import FrameStrip

@Suite("ControlPanelViewState Tests")
struct RecordingPanelViewStateTests {

    @Test("액션 버튼 최소 폭은 모든 phase에서 동일하게 유지된다")
    func actionButtonMinimumWidthStaysStableAcrossPhases() {
        let adjusting = ControlPanelViewState.make(for: .adjusting)
        let recording = ControlPanelViewState.make(for: .recording)
        let finalizing = ControlPanelViewState.make(for: .finalizing)

        #expect(adjusting.actionMinWidth == CGFloat(80))
        #expect(recording.actionMinWidth == adjusting.actionMinWidth)
        #expect(finalizing.actionMinWidth == recording.actionMinWidth)
    }

    @Test("adjusting 패널은 활성 record 버튼과 설정 칩을 사용한다")
    func adjustingPanelUsesRecordControls() {
        let state = ControlPanelViewState.make(for: .adjusting)

        #expect(state.showsAdjustingChips)
        #expect(!state.showsRecordingStatus)
        #expect(state.isCloseEnabled)
        #expect(state.isActionEnabled)
        #expect(!state.showsActionSpinner)
        #expect(state.actionTitle == String(localized: "Record"))
    }

    @Test("recording 패널은 활성 stop 버튼과 펄스 점을 사용한다")
    func recordingPanelUsesEnabledControls() {
        let state = ControlPanelViewState.make(for: .recording)

        #expect(!state.showsAdjustingChips)
        #expect(state.showsRecordingStatus)
        #expect(state.isCloseEnabled)
        #expect(state.isActionEnabled)
        #expect(!state.showsActionSpinner)
        #expect(state.actionTitle == String(localized: "Stop"))
        #expect(state.isRecordingDotPulsing)
        #expect(state.recordingDotOpacity == 1.0)
    }

    @Test("finalizing 패널은 spinner와 비활성 컨트롤을 사용한다")
    func finalizingPanelUsesDisabledSpinner() {
        let state = ControlPanelViewState.make(for: .finalizing)

        #expect(!state.showsAdjustingChips)
        #expect(state.showsRecordingStatus)
        #expect(!state.isCloseEnabled)
        #expect(!state.isActionEnabled)
        #expect(state.showsActionSpinner)
        #expect(state.actionTitle == nil)
        #expect(!state.isRecordingDotPulsing)
        #expect(state.recordingDotOpacity == 0.45)
    }
}
