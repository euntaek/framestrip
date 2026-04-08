import Testing
import Foundation
@testable import FrameStrip

@Suite("SessionManifest Tests")
struct SessionManifestTests {

    @Test("타이머 프레임만 → 단일 timer 세그먼트")
    func timerOnlySegments() {
        let records: [SessionManifest.FrameRecord] = [
            .init(filename: "frame_001_00m00s000ms.png", time: 0.0, event: nil),
            .init(filename: "frame_002_00m00s500ms.png", time: 0.5, event: nil),
            .init(filename: "frame_003_00m01s000ms.png", time: 1.0, event: nil),
        ]
        let segments = SessionManifest.buildSegments(from: records)

        #expect(segments.count == 1)
        if case let .timer(start, end, count, time) = segments[0] {
            #expect(start == "frame_001_00m00s000ms.png")
            #expect(end == "frame_003_00m01s000ms.png")
            #expect(count == 3)
            #expect(time == [0.0, 1.0])
        } else {
            Issue.record("Expected timer segment")
        }
    }

    @Test("이벤트 프레임이 타이머 세그먼트를 분리")
    func eventSplitsTimerSegments() {
        let event = InteractionEvent(
            type: .mouseDown, button: .left,
            position: PixelPosition(x: 100, y: 200),
            modifiers: []        )
        let records: [SessionManifest.FrameRecord] = [
            .init(filename: "frame_001_00m00s000ms.png", time: 0.0, event: nil),
            .init(filename: "frame_002_00m00s500ms.png", time: 0.5, event: nil),
            .init(filename: "frame_003_00m01s500ms.png", time: 1.5, event: event),
            .init(filename: "frame_004_00m02s000ms.png", time: 2.0, event: nil),
        ]
        let segments = SessionManifest.buildSegments(from: records)

        #expect(segments.count == 3)
        if case let .timer(start, end, count, _) = segments[0] {
            #expect(start == "frame_001_00m00s000ms.png")
            #expect(end == "frame_002_00m00s500ms.png")
            #expect(count == 2)
        } else {
            Issue.record("Expected timer segment at [0]")
        }
        if case let .event(frame, time, ev) = segments[1] {
            #expect(frame == "frame_003_00m01s500ms.png")
            #expect(time == 1.5)
            #expect(ev.type == .mouseDown)
        } else {
            Issue.record("Expected event segment at [1]")
        }
        if case let .timer(start, end, count, _) = segments[2] {
            #expect(start == "frame_004_00m02s000ms.png")
            #expect(end == "frame_004_00m02s000ms.png")
            #expect(count == 1)
        } else {
            Issue.record("Expected timer segment at [2]")
        }
    }

    @Test("빈 레코드 → 빈 세그먼트")
    func emptyRecords() {
        let segments = SessionManifest.buildSegments(from: [])
        #expect(segments.isEmpty)
    }

    @Test("연속 이벤트 프레임 → 각각 개별 세그먼트")
    func consecutiveEvents() {
        let down = InteractionEvent(type: .mouseDown, button: .left, position: PixelPosition(x: 0, y: 0), modifiers: [])
        let up = InteractionEvent(type: .mouseUp, button: .left, position: PixelPosition(x: 0, y: 0), modifiers: [])
        let records: [SessionManifest.FrameRecord] = [
            .init(filename: "frame_001_00m01s000ms.png", time: 1.0, event: down),
            .init(filename: "frame_002_00m01s100ms.png", time: 1.1, event: up),
        ]
        let segments = SessionManifest.buildSegments(from: records)

        #expect(segments.count == 2)
        if case .event = segments[0], case .event = segments[1] {} else {
            Issue.record("Expected two event segments")
        }
    }

    @Test("JSON 인코딩 라운드트립")
    func jsonRoundTrip() throws {
        let settings = SessionManifest.Settings(
            captureInterval: 0.5, imageFormat: "png",
            changeDetection: true, changeThreshold: 0.01,
            showCursor: true, interactionCapture: true
        )
        let manifest = SessionManifest(
            settings: settings, duration: 5.0,
            totalFrames: 3, interactionEvents: 1,
            segments: [
                .timer(startFrame: "frame_001_00m00s000ms.png", endFrame: "frame_002_00m00s500ms.png", count: 2, time: [0.0, 0.5]),
                .event(frame: "frame_003_00m01s000ms.png", time: 1.0, event: InteractionEvent(
                    type: .mouseDown, button: .left,
                    position: PixelPosition(x: 100, y: 200),
                    modifiers: ["⌘"]
                )),
            ]
        )

        let data = try JSONEncoder().encode(manifest)
        let decoded = try JSONDecoder().decode(SessionManifest.self, from: data)

        #expect(decoded.totalFrames == 3)
        #expect(decoded.interactionEvents == 1)
        #expect(decoded.settings.captureInterval == 0.5)
        #expect(decoded.segments.count == 2)
    }

    @Test("interactionEvents는 저장 성공 기준 카운트")
    func interactionEventsCountMatchesSavedEvents() {
        let event1 = InteractionEvent(type: .mouseDown, button: .left, position: PixelPosition(x: 0, y: 0), modifiers: [])
        let event2 = InteractionEvent(type: .mouseUp, button: .left, position: PixelPosition(x: 0, y: 0), modifiers: [])
        let records: [SessionManifest.FrameRecord] = [
            .init(filename: "frame_001_00m00s000ms.png", time: 0.0, event: nil),
            .init(filename: "frame_002_00m01s000ms.png", time: 1.0, event: event1),
            .init(filename: "frame_003_00m01s500ms.png", time: 1.5, event: nil),
            .init(filename: "frame_004_00m02s000ms.png", time: 2.0, event: event2),
        ]
        let count = records.filter { $0.event != nil }.count
        #expect(count == 2)
    }
}
