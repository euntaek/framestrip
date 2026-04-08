import Testing
@testable import FrameStrip

@Suite("AppState Tests")
struct AppStateTests {

    @Test("finalizing에 들어간 뒤 늦은 표시 업데이트는 무시된다")
    func finalizingFreezesDisplayMetrics() {
        let state = AppState()
        state.elapsedTime = 3.2
        state.frameCount = 12
        state.skippedFrameCount = 2

        state.status = .finalizing

        state.elapsedTime = 4.8
        state.frameCount = 15
        state.skippedFrameCount = 5

        #expect(state.elapsedTime == 3.2)
        #expect(state.frameCount == 12)
        #expect(state.skippedFrameCount == 2)
    }

    @Test("idle로 복귀하면 다음 세션을 위해 표시 카운트가 비워진다")
    func returningToIdleClearsTransientDisplayMetrics() {
        let state = AppState()
        state.elapsedTime = 5.1
        state.frameCount = 24
        state.skippedFrameCount = 4

        state.status = .finalizing
        state.status = .idle

        #expect(state.elapsedTime == 0)
        #expect(state.frameCount == 0)
        #expect(state.skippedFrameCount == 0)
    }
}
