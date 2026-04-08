import AppKit

class RecordingBorderWindow: NSWindow {
    private let borderView: RecordingBorderView

    /// - Parameter region: CG coords (top-left origin). Converted to AppKit (bottom-left) here.
    /// - Parameter screen: target screen
    init(region: CGRect, screen: NSScreen) {
        let borderWidth: CGFloat = 2

        let appKitRect = CoordinateUtils.cgToAppKitWindowFrame(region, on: screen)

        let expandedRect = appKitRect.insetBy(dx: -borderWidth, dy: -borderWidth)
        borderView = RecordingBorderView(frame: NSRect(origin: .zero, size: expandedRect.size))

        super.init(contentRect: expandedRect, styleMask: .borderless, backing: .buffered, defer: false)

        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]
        self.isOpaque = false
        self.hasShadow = false
        self.backgroundColor = .clear
        self.ignoresMouseEvents = true  // mouse events pass through
        self.isReleasedWhenClosed = false
        self.contentView = borderView
    }

    func startPulsing() { borderView.startPulsing() }
    func stopPulsing() { borderView.stopPulsing(); close() }
}

private class RecordingBorderView: NSView {
    private var pulseTimer: Timer?
    private var opacity: CGFloat = 1.0
    private var increasing = false

    override func draw(_ dirtyRect: NSRect) {
        // Red border: 2px, #EF4444, 1.5s pulse — spec
        let color = AppColors.recording.withAlphaComponent(opacity)
        color.setStroke()
        let path = NSBezierPath(rect: bounds.insetBy(dx: 1, dy: 1))
        path.lineWidth = 2
        path.stroke()
    }

    func startPulsing() {
        // 1.5s cycle: opacity 0.3 ↔ 1.0
        let timer = Timer(timeInterval: 1.5 / 30, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.increasing {
                self.opacity += 0.7 / 15
                if self.opacity >= 1.0 { self.opacity = 1.0; self.increasing = false }
            } else {
                self.opacity -= 0.7 / 15
                if self.opacity <= 0.3 { self.opacity = 0.3; self.increasing = true }
            }
            self.needsDisplay = true
        }
        RunLoop.current.add(timer, forMode: .common)
        pulseTimer = timer
    }

    func stopPulsing() {
        pulseTimer?.invalidate()
        pulseTimer = nil
    }
}
