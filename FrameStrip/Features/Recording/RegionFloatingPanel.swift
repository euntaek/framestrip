import AppKit

class RegionFloatingPanel: NSPanel {
    private static let handlePadding: CGFloat = 10
    private static let badgeBottomPadding: CGFloat = 28

    private let floatingView: RegionFloatingView

    var onRegionChanged: ((CGRect) -> Void)?
    var onEnterPressed: (() -> Void)?
    var onCancel: (() -> Void)?

    /// globalRegion: 글로벌 AppKit 좌표의 영역 rect
    init(globalRegion: CGRect) {
        let padding = Self.handlePadding
        let bottomExtra = Self.badgeBottomPadding
        let panelFrame = NSRect(
            x: globalRegion.origin.x - padding,
            y: globalRegion.origin.y - bottomExtra,
            width: globalRegion.width + padding * 2,
            height: globalRegion.height + padding + bottomExtra
        )
        self.floatingView = RegionFloatingView(
            frame: NSRect(origin: .zero, size: panelFrame.size),
            padding: padding,
            bottomPadding: bottomExtra
        )

        super.init(
            contentRect: panelFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)) + 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isOpaque = false
        hasShadow = false
        backgroundColor = .clear
        isReleasedWhenClosed = false
        isMovableByWindowBackground = false

        floatingView.onRegionChanged = { [weak self] in
            self?.notifyRegionChanged()
        }
        floatingView.onGlobalResizeUpdate = { [weak self] globalRegion in
            self?.updatePanelFrame(for: globalRegion)
        }
        floatingView.onEnterPressed = { [weak self] in
            self?.onEnterPressed?()
        }
        floatingView.onCancel = { [weak self] in
            self?.onCancel?()
        }

        contentView = floatingView
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// 현재 영역의 글로벌 AppKit rect (패딩 제외)
    var globalRegionRect: CGRect {
        let padding = Self.handlePadding
        let bottomExtra = Self.badgeBottomPadding
        return CGRect(
            x: frame.origin.x + padding,
            y: frame.origin.y + bottomExtra,
            width: frame.width - padding * 2,
            height: frame.height - padding - bottomExtra
        )
    }

    private func notifyRegionChanged() {
        onRegionChanged?(globalRegionRect)
    }

    private func updatePanelFrame(for globalRegion: NSRect) {
        let padding = Self.handlePadding
        let bottomExtra = Self.badgeBottomPadding
        let newPanelFrame = NSRect(
            x: globalRegion.origin.x - padding,
            y: globalRegion.origin.y - bottomExtra,
            width: globalRegion.width + padding * 2,
            height: globalRegion.height + padding + bottomExtra
        )

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            self.setFrame(newPanelFrame, display: false)
            let actualSize = self.frame.size
            self.floatingView.frame = NSRect(origin: .zero, size: actualSize)
            self.floatingView.resetRegionFromPadding()
            self.floatingView.needsDisplay = true
        }

        notifyRegionChanged()
    }

}

// MARK: - RegionFloatingView

class RegionFloatingView: NSView {
    var onRegionChanged: (() -> Void)?
    var onGlobalResizeUpdate: ((NSRect) -> Void)?
    var onEnterPressed: (() -> Void)?
    var onCancel: (() -> Void)?

    enum HandlePosition {
        case topLeft, topRight, bottomLeft, bottomRight
        case topCenter, bottomCenter, leftCenter, rightCenter
    }

    private let padding: CGFloat
    private let bottomPadding: CGFloat
    private var regionRect: NSRect
    private var trackingArea: NSTrackingArea?

    private var activeHandle: HandlePosition?
    private var isDraggingRegion = false
    private var dragOffset: NSPoint = .zero
    /// 리사이즈 시작 시점의 글로벌 영역 rect — 고정 가장자리의 앵커
    private var resizeAnchorRect: CGRect = .zero

    private static let handleSize: CGFloat = 10
    private static let handleHitSize: CGFloat = 20
    private static let minRegionSize: CGFloat = 10

    override var acceptsFirstResponder: Bool { true }

    init(frame: NSRect, padding: CGFloat, bottomPadding: CGFloat) {
        self.padding = padding
        self.bottomPadding = bottomPadding
        self.regionRect = NSRect(
            x: padding,
            y: bottomPadding,
            width: frame.width - padding * 2,
            height: frame.height - padding - bottomPadding
        )
        super.init(frame: frame)
        setupTracking()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 패널 frame 변경 후 regionRect를 패딩 기준으로 재계산
    func resetRegionFromPadding() {
        regionRect = NSRect(
            x: padding,
            y: bottomPadding,
            width: bounds.width - padding * 2,
            height: bounds.height - padding - bottomPadding
        )
    }

    private func setupTracking() {
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .cursorUpdate],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        setupTracking()
    }

    // MARK: - Hit Testing

    private func handleCenters(for rect: NSRect) -> [(HandlePosition, NSPoint)] {
        [
            (.topLeft, NSPoint(x: rect.minX, y: rect.maxY)),
            (.topRight, NSPoint(x: rect.maxX, y: rect.maxY)),
            (.bottomLeft, NSPoint(x: rect.minX, y: rect.minY)),
            (.bottomRight, NSPoint(x: rect.maxX, y: rect.minY)),
            (.topCenter, NSPoint(x: rect.midX, y: rect.maxY)),
            (.bottomCenter, NSPoint(x: rect.midX, y: rect.minY)),
            (.leftCenter, NSPoint(x: rect.minX, y: rect.midY)),
            (.rightCenter, NSPoint(x: rect.maxX, y: rect.midY)),
        ]
    }

    private func handleAt(_ point: NSPoint) -> HandlePosition? {
        let hitSize = Self.handleHitSize
        let halfHit = hitSize / 2
        for (handle, center) in handleCenters(for: regionRect) {
            let hitRect = NSRect(x: center.x - halfHit, y: center.y - halfHit, width: hitSize, height: hitSize)
            if hitRect.contains(point) {
                return handle
            }
        }
        return nil
    }

    private func isInsideRegion(_ point: NSPoint) -> Bool {
        regionRect.contains(point)
    }

    private static let nwseCursor: NSCursor = {
        let size: CGFloat = 16
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
            NSColor.black.setStroke()
            let path = NSBezierPath()
            path.move(to: NSPoint(x: 2, y: 14)); path.line(to: NSPoint(x: 14, y: 2))
            path.move(to: NSPoint(x: 2, y: 14)); path.line(to: NSPoint(x: 6, y: 14))
            path.move(to: NSPoint(x: 2, y: 14)); path.line(to: NSPoint(x: 2, y: 10))
            path.move(to: NSPoint(x: 14, y: 2)); path.line(to: NSPoint(x: 10, y: 2))
            path.move(to: NSPoint(x: 14, y: 2)); path.line(to: NSPoint(x: 14, y: 6))
            path.lineWidth = 1.5; path.stroke()
            return true
        }
        return NSCursor(image: image, hotSpot: NSPoint(x: 8, y: 8))
    }()

    private static let neswCursor: NSCursor = {
        let size: CGFloat = 16
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
            NSColor.black.setStroke()
            let path = NSBezierPath()
            path.move(to: NSPoint(x: 14, y: 14)); path.line(to: NSPoint(x: 2, y: 2))
            path.move(to: NSPoint(x: 14, y: 14)); path.line(to: NSPoint(x: 10, y: 14))
            path.move(to: NSPoint(x: 14, y: 14)); path.line(to: NSPoint(x: 14, y: 10))
            path.move(to: NSPoint(x: 2, y: 2)); path.line(to: NSPoint(x: 6, y: 2))
            path.move(to: NSPoint(x: 2, y: 2)); path.line(to: NSPoint(x: 2, y: 6))
            path.lineWidth = 1.5; path.stroke()
            return true
        }
        return NSCursor(image: image, hotSpot: NSPoint(x: 8, y: 8))
    }()

    private func cursorForHandle(_ handle: HandlePosition) -> NSCursor {
        switch handle {
        case .topLeft, .bottomRight: return Self.nwseCursor
        case .topRight, .bottomLeft: return Self.neswCursor
        case .topCenter, .bottomCenter: return NSCursor.resizeUpDown
        case .leftCenter, .rightCenter: return NSCursor.resizeLeftRight
        }
    }

    override func cursorUpdate(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let handle = handleAt(point) {
            cursorForHandle(handle).set()
        } else if isInsideRegion(point) {
            NSCursor.openHand.set()
        } else {
            NSCursor.arrow.set()
        }
    }

    override func mouseMoved(with event: NSEvent) {
        cursorUpdate(with: event)
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        // macOS 윈도우 서버는 완전 투명 픽셀의 클릭을 뒤 윈도우로 전달.
        // 전체 bounds를 최소 알파로 채워 패널 영역 전체의 마우스 이벤트 수신 확보.
        // 시각적 렌더링(테두리, 핸들, 배지)은 각 모니터별 오버레이 윈도우가 담당.
        NSColor(white: 0, alpha: 0.005).setFill()
        bounds.fill()
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let handle = handleAt(point) {
            activeHandle = handle
            if let windowFrame = window?.frame {
                resizeAnchorRect = CGRect(
                    x: windowFrame.origin.x + padding,
                    y: windowFrame.origin.y + bottomPadding,
                    width: windowFrame.width - padding * 2,
                    height: windowFrame.height - padding - bottomPadding
                )
            }
        } else if isInsideRegion(point) {
            isDraggingRegion = true
            // SelectionControlPanel 패턴: 글로벌 마우스 → 패널 origin 오프셋 저장
            guard let window else { return }
            let mouseLocation = NSEvent.mouseLocation
            dragOffset = NSPoint(
                x: mouseLocation.x - window.frame.origin.x,
                y: mouseLocation.y - window.frame.origin.y
            )
            NSCursor.closedHand.set()
        }
    }

    override func mouseDragged(with event: NSEvent) {
        if activeHandle != nil {
            resizeRegion(with: event)
        } else if isDraggingRegion {
            moveRegion(with: event)
        }
    }

    override func mouseUp(with event: NSEvent) {
        activeHandle = nil
        resizeAnchorRect = .zero
        if isDraggingRegion {
            isDraggingRegion = false
            let point = convert(event.locationInWindow, from: nil)
            if isInsideRegion(point) {
                NSCursor.openHand.set()
            }
        }
        onRegionChanged?()
    }

    private func moveRegion(with event: NSEvent) {
        guard let window else { return }
        let mouseLocation = NSEvent.mouseLocation
        // SelectionControlPanel 패턴: 글로벌 마우스 위치 - 저장된 오프셋 = 새 패널 origin
        window.setFrameOrigin(NSPoint(
            x: mouseLocation.x - dragOffset.x,
            y: mouseLocation.y - dragOffset.y
        ))
        needsDisplay = true
        onRegionChanged?()
    }

    /// 고정 가장자리는 mouseDown 시 저장한 앵커에서 직접 읽어 NSWindow 프레임 반올림 오차 누적을 방지한다.
    private func resizeRegion(with event: NSEvent) {
        guard let handle = activeHandle else { return }
        let mouse = NSEvent.mouseLocation
        let anchor = resizeAnchorRect
        let minSize = Self.minRegionSize

        var newMinX = anchor.minX
        var newMinY = anchor.minY
        var newMaxX = anchor.maxX
        var newMaxY = anchor.maxY

        switch handle {
        case .topLeft:
            newMinX = min(mouse.x, anchor.maxX - minSize)
            newMaxY = max(mouse.y, anchor.minY + minSize)
        case .topRight:
            newMaxX = max(mouse.x, anchor.minX + minSize)
            newMaxY = max(mouse.y, anchor.minY + minSize)
        case .bottomLeft:
            newMinX = min(mouse.x, anchor.maxX - minSize)
            newMinY = min(mouse.y, anchor.maxY - minSize)
        case .bottomRight:
            newMaxX = max(mouse.x, anchor.minX + minSize)
            newMinY = min(mouse.y, anchor.maxY - minSize)
        case .topCenter:
            newMaxY = max(mouse.y, anchor.minY + minSize)
        case .bottomCenter:
            newMinY = min(mouse.y, anchor.maxY - minSize)
        case .leftCenter:
            newMinX = min(mouse.x, anchor.maxX - minSize)
        case .rightCenter:
            newMaxX = max(mouse.x, anchor.minX + minSize)
        }

        let newGlobalRegion = NSRect(
            x: newMinX, y: newMinY,
            width: newMaxX - newMinX, height: newMaxY - newMinY
        )
        onGlobalResizeUpdate?(newGlobalRegion)
    }

    // MARK: - Keyboard Events

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case KeyCodes.returnKey:
            onEnterPressed?()

        case KeyCodes.escape:
            onCancel?()

        case KeyCodes.leftArrow, KeyCodes.rightArrow, KeyCodes.upArrow, KeyCodes.downArrow:
            guard let window else { return }
            let step: CGFloat = event.modifierFlags.contains(.shift) ? 10 : 1
            var dx: CGFloat = 0
            var dy: CGFloat = 0
            switch event.keyCode {
            case KeyCodes.leftArrow: dx = -step
            case KeyCodes.rightArrow: dx = step
            case KeyCodes.upArrow: dy = step
            case KeyCodes.downArrow: dy = -step
            default: break
            }
            window.setFrameOrigin(NSPoint(
                x: window.frame.origin.x + dx,
                y: window.frame.origin.y + dy
            ))
            onRegionChanged?()

        default:
            break
        }
    }

}
