import Foundation

struct PixelPosition: Codable, Sendable, Equatable {
    let x: Int
    let y: Int
}

struct InteractionEvent: Codable, Sendable {
    enum EventType: String, Codable, Sendable {
        case mouseDown
        case mouseUp
        case dragStart
    }

    enum MouseButton: String, Codable, Sendable {
        case left
        case right
        case other
    }

    let type: EventType
    let button: MouseButton
    let position: PixelPosition
    let modifiers: [String]
}
