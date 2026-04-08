import Foundation

struct SessionManifest: Codable {
    struct Settings: Codable {
        let captureInterval: Double
        let imageFormat: String
        let changeDetection: Bool
        let changeThreshold: Double
        let showCursor: Bool
        let interactionCapture: Bool
    }

    struct FrameRecord {
        let filename: String
        let time: TimeInterval
        let event: InteractionEvent?
    }

    enum Segment: Codable {
        case timer(startFrame: String, endFrame: String, count: Int, time: [TimeInterval])
        case event(frame: String, time: TimeInterval, event: InteractionEvent)

        enum CodingKeys: String, CodingKey {
            case type, startFrame, endFrame, count, time, frame, event
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case let .timer(startFrame, endFrame, count, time):
                try container.encode("timer", forKey: .type)
                try container.encode(startFrame, forKey: .startFrame)
                try container.encode(endFrame, forKey: .endFrame)
                try container.encode(count, forKey: .count)
                try container.encode(time, forKey: .time)
            case let .event(frame, time, event):
                try container.encode("event", forKey: .type)
                try container.encode(frame, forKey: .frame)
                try container.encode(time, forKey: .time)
                try container.encode(event, forKey: .event)
            }
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)
            switch type {
            case "timer":
                let startFrame = try container.decode(String.self, forKey: .startFrame)
                let endFrame = try container.decode(String.self, forKey: .endFrame)
                let count = try container.decode(Int.self, forKey: .count)
                let time = try container.decode([TimeInterval].self, forKey: .time)
                self = .timer(startFrame: startFrame, endFrame: endFrame, count: count, time: time)
            case "event":
                let frame = try container.decode(String.self, forKey: .frame)
                let time = try container.decode(TimeInterval.self, forKey: .time)
                let event = try container.decode(InteractionEvent.self, forKey: .event)
                self = .event(frame: frame, time: time, event: event)
            default:
                throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown segment type: \(type)")
            }
        }
    }

    static let formatVersion = 1

    let settings: Settings
    let duration: TimeInterval
    let totalFrames: Int
    let interactionEvents: Int
    let segments: [Segment]

    // MARK: - Legend

    private static let legend: [String: String] = [
        "duration": "Total recording duration in seconds since recording started.",
        "totalFrames": "Total number of saved image files in this session.",
        "interactionEvents": "Number of saved event-triggered frames in this session.",

        "settings.captureInterval": "Timer-based capture interval in seconds.",
        "settings.imageFormat": "Image file format: png or jpeg.",
        "settings.changeDetection": "Whether timer frames are saved only when screen content changes.",
        "settings.changeThreshold": "Minimum pixel difference ratio to detect a change (0.0-1.0).",
        "settings.showCursor": "Whether the mouse cursor is visible in captured frames.",
        "settings.interactionCapture": "Whether click/drag events trigger extra captures.",

        "segments": "Chronologically ordered array of saved frame segments.",
        "segments[].type": "Segment type. One of: timer, event.",

        "segments[type=timer].startFrame": "First saved filename in this timer segment.",
        "segments[type=timer].endFrame": "Last saved filename in this timer segment.",
        "segments[type=timer].count": "Number of saved files in this timer segment.",
        "segments[type=timer].time": "[startSeconds, endSeconds] since recording started.",

        "segments[type=event].frame": "Saved filename for this event-triggered frame.",
        "segments[type=event].time": "Capture time in seconds since recording started.",
        "segments[type=event].event.type": "Interaction type: mouseDown, mouseUp, or dragStart.",
        "segments[type=event].event.button": "Mouse button: left, right, or other.",
        "segments[type=event].event.position.x": "Horizontal pixel coordinate in the saved image.",
        "segments[type=event].event.position.y": "Vertical pixel coordinate in the saved image.",
        "segments[type=event].event.modifiers": "Modifier keys pressed at event time.",
    ]

    // MARK: - Custom Codable

    enum CodingKeys: String, CodingKey {
        case formatVersion, _legend, settings, duration, totalFrames, interactionEvents, segments
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.formatVersion, forKey: .formatVersion)
        try container.encode(Self.legend, forKey: ._legend)
        try container.encode(settings, forKey: .settings)
        try container.encode(duration, forKey: .duration)
        try container.encode(totalFrames, forKey: .totalFrames)
        try container.encode(interactionEvents, forKey: .interactionEvents)
        try container.encode(segments, forKey: .segments)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        settings = try container.decode(Settings.self, forKey: .settings)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        totalFrames = try container.decode(Int.self, forKey: .totalFrames)
        interactionEvents = try container.decode(Int.self, forKey: .interactionEvents)
        segments = try container.decode([Segment].self, forKey: .segments)
    }

    init(settings: Settings, duration: TimeInterval, totalFrames: Int, interactionEvents: Int, segments: [Segment]) {
        self.settings = settings
        self.duration = duration
        self.totalFrames = totalFrames
        self.interactionEvents = interactionEvents
        self.segments = segments
    }

    // MARK: - Segment Builder

    static func buildSegments(from records: [FrameRecord]) -> [Segment] {
        var segments: [Segment] = []
        var batchStart: FrameRecord?
        var batchEnd: FrameRecord?
        var batchCount = 0

        func roundMs(_ t: TimeInterval) -> TimeInterval {
            (t * 1000).rounded() / 1000
        }

        func flushBatch() {
            guard let start = batchStart, let end = batchEnd else { return }
            segments.append(.timer(
                startFrame: start.filename, endFrame: end.filename,
                count: batchCount, time: [roundMs(start.time), roundMs(end.time)]
            ))
            batchStart = nil
            batchEnd = nil
            batchCount = 0
        }

        for record in records {
            if let event = record.event {
                flushBatch()
                segments.append(.event(frame: record.filename, time: roundMs(record.time), event: event))
            } else {
                if batchStart == nil { batchStart = record }
                batchEnd = record
                batchCount += 1
            }
        }
        flushBatch()

        return segments
    }

    // MARK: - JSON Writer

    func write(to directory: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        let fileURL = directory.appendingPathComponent("session.json")
        try data.write(to: fileURL)
    }
}
