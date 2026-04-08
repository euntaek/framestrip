import Testing
import Foundation
@testable import FrameStrip

@Suite("RecordingSession Tests")
struct RecordingSessionTests {

    @Test("finalizing 상태는 recording으로 취급되지 않는다")
    func finalizingIsNotRecording() {
        let state = AppState()
        state.status = .finalizing

        #expect(!state.isRecording)
    }

    @Test("maxFrames 도달 시 자동 중지")
    func autoStopByMaxFrames() {
        let session = RecordingSession.AutoStopChecker(maxFrames: 5, maxDuration: 0)
        #expect(!session.shouldStop(frameCount: 4, elapsed: 10))
        #expect(session.shouldStop(frameCount: 5, elapsed: 10))
    }

    @Test("maxDuration 도달 시 자동 중지")
    func autoStopByMaxDuration() {
        let session = RecordingSession.AutoStopChecker(maxFrames: 0, maxDuration: 60)
        #expect(!session.shouldStop(frameCount: 100, elapsed: 59))
        #expect(session.shouldStop(frameCount: 100, elapsed: 60))
    }

    @Test("maxFrames=0, maxDuration=0이면 자동 중지 없음")
    func noAutoStop() {
        let session = RecordingSession.AutoStopChecker(maxFrames: 0, maxDuration: 0)
        #expect(!session.shouldStop(frameCount: 99999, elapsed: 99999))
    }

    @Test("maxFrames와 maxDuration 동시 설정: 먼저 도달하는 조건")
    func autoStopBothSet() {
        let session = RecordingSession.AutoStopChecker(maxFrames: 100, maxDuration: 30)
        #expect(session.shouldStop(frameCount: 50, elapsed: 30))
        #expect(session.shouldStop(frameCount: 100, elapsed: 15))
    }

    @Test("연속 실패 3회 시 중지")
    func consecutiveFailureTracking() {
        var tracker = RecordingSession.FailureTracker()
        tracker.recordFailure()
        #expect(!tracker.shouldStop)
        tracker.recordFailure()
        #expect(!tracker.shouldStop)
        tracker.recordFailure()
        #expect(tracker.shouldStop)
    }

    @Test("성공 시 연속 실패 카운터 리셋")
    func failureResetOnSuccess() {
        var tracker = RecordingSession.FailureTracker()
        tracker.recordFailure()
        tracker.recordFailure()
        tracker.recordSuccess()
        #expect(!tracker.shouldStop)
        tracker.recordFailure()
        #expect(!tracker.shouldStop)
    }

    @Test("display change 종료 이유는 사용자 메시지를 가진다")
    func displayChangeStopReasonHasMessage() {
        #expect(RecordingSession.StopReason.displayChange.userFacingErrorMessage == String(localized: "Recording stopped because display settings changed"))
        #expect(RecordingSession.StopReason.manual.userFacingErrorMessage == nil)
    }

    @Test("finalization은 pending save가 남아 있으면 drain까지 기다린다")
    func finalizationWaitsForPendingSaves() {
        var tracker = RecordingSession.FinalizationTracker()
        tracker.beginPendingSave()
        let pendingBeforeDrain = tracker.pendingSaves
        let startedFinalization = tracker.beginFinalization(reason: .manual)
        let drained = tracker.finishPendingSave()

        #expect(!startedFinalization)
        #expect(tracker.isFinalizing)
        #expect(pendingBeforeDrain == 1)
        #expect(drained)
    }

    @Test("finalizing 중 늦은 save failure는 최종 에러로 승격된다")
    func finalizationPromotesLateSaveFailure() {
        var tracker = RecordingSession.FinalizationTracker()
        tracker.beginPendingSave()
        let startedFinalization = tracker.beginFinalization(reason: .manual)
        let drainedWithError = tracker.finishPendingSave(errorMessage: "이미지 저장에 실패했습니다")

        #expect(!startedFinalization)
        #expect(drainedWithError)
        #expect(tracker.errorMessage == "이미지 저장에 실패했습니다")
    }

    @Test("stop 요청은 recording 상태에서 한 번만 생성된다")
    func stopRequestIsEmittedOnce() {
        var tracker = RecordingSession.FinalizationTracker()
        let firstRequest = tracker.shouldRequestStop(for: .autoStop)
        let secondRequest = tracker.shouldRequestStop(for: .displayChange)
        let immediateFinalization = tracker.beginFinalization(reason: .autoStop)
        let requestAfterFinalization = tracker.shouldRequestStop(for: .manual)

        #expect(firstRequest)
        #expect(!secondRequest)
        #expect(immediateFinalization)
        #expect(!requestAfterFinalization)
    }
}
