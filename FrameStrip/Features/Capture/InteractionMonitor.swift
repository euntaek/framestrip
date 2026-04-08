import AppKit

class InteractionMonitor {
    typealias EventHandler = (NSEvent) -> Void

    private var globalMonitor: Any?
    private var isDragging = false

    var onInteraction: EventHandler?

    func start() {
        stop()
        isDragging = false

        let eventMask: NSEvent.EventTypeMask = [
            .leftMouseDown, .leftMouseUp,
            .rightMouseDown, .rightMouseUp,
            .otherMouseDown, .otherMouseUp,
            .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
        ]

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: eventMask) { [weak self] event in
            self?.handleEvent(event)
        }
    }

    func stop() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        isDragging = false
    }

    private func handleEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            isDragging = false
            onInteraction?(event)

        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            isDragging = false
            onInteraction?(event)

        case .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            if !isDragging {
                isDragging = true
                onInteraction?(event)
            }

        default:
            break
        }
    }

    deinit {
        stop()
    }
}
