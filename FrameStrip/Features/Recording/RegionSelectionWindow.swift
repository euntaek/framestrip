import AppKit

class RegionSelectionWindow: NSPanel {
    private var onRegionReady: ((CGRect, NSScreen) -> Void)?
    private var onCancel: (() -> Void)?
    private let selectionView: RegionSelectionView

    init(
        screen: NSScreen,
        onRegionReady: @escaping (CGRect, NSScreen) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onRegionReady = onRegionReady
        self.onCancel = onCancel
        self.selectionView = RegionSelectionView(frame: screen.frame)
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .screenSaver
        isOpaque = false
        hasShadow = false
        backgroundColor = .clear
        ignoresMouseEvents = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        selectionView.onRegionReady = { [weak self] rect in
            guard let self, let screen = self.screen else { return }
            self.onRegionReady?(rect, screen)
        }
        selectionView.onCancel = { [weak self] in
            guard let self else { return }
            self.onCancel?()
        }
        contentView = selectionView
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func resetToOverlay() {
        selectionView.resetToDragging()
    }

    func updateCutout(globalRect: CGRect?) {
        selectionView.updateCutout(globalRect: globalRect)
    }

    func setTransitionProgress(_ progress: CGFloat) {
        selectionView.transitionProgress = progress
        selectionView.needsDisplay = true
    }
}

// MARK: - RegionSelectionView

class RegionSelectionView: NSView {
    var onRegionReady: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?

    private var startPoint: NSPoint?
    private var currentRect: NSRect?
    private var cutoutRect: NSRect?
    private var regionLocalRect: NSRect?
    private var trackingArea: NSTrackingArea?
    var transitionProgress: CGFloat = 0

    private static let minRegionSize: CGFloat = 10
    private static let handleSize: CGFloat = 10

    private static let handleShadow: NSShadow = {
        let s = NSShadow()
        s.shadowColor = AppColors.handleShadow
        s.shadowBlurRadius = 2
        s.shadowOffset = NSSize(width: 0, height: -1)
        return s
    }()

    private static let badgeFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
    private static let badgeAttributes: [NSAttributedString.Key: Any] = [
        .font: badgeFont,
        .foregroundColor: AppColors.badgeText,
    ]

    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupTracking()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupTracking() {
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .cursorUpdate],
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

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.crosshair.set()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        AppColors.overlayBackground.setFill()
        bounds.fill()

        // dragging 중 선택 영역 표시
        if let rect = currentRect {
            NSColor.clear.setFill()
            rect.fill(using: .copy)
            NSColor.white.setStroke()
            let borderPath = NSBezierPath(rect: rect)
            borderPath.lineWidth = 1.0
            borderPath.stroke()
            drawSizeBadge(for: rect)
        }

        // adjusting 중: cutout + 테두리 + 핸들 + 배지
        if let cutout = cutoutRect, let regionLocal = regionLocalRect {
            NSColor.clear.setFill()
            cutout.fill(using: .copy)
            drawRegionBorder(cutout: cutout, regionLocal: regionLocal)
            if transitionProgress < 0.01 {
                drawRegionHandles(regionLocal: regionLocal)
            }
            drawSizeBadge(for: regionLocal)
        }
    }

    /// 모니터 경계가 아닌 실제 영역 가장자리에만 테두리를 그림
    private func drawRegionBorder(cutout: NSRect, regionLocal: NSRect) {
        let borderColor: NSColor
        if transitionProgress < 0.01 {
            borderColor = .white
        } else {
            borderColor = NSColor.white.blended(withFraction: transitionProgress, of: AppColors.recording) ?? AppColors.recording
        }
        borderColor.setStroke()

        let path = NSBezierPath()
        path.lineWidth = 2.0
        let gap = transitionProgress < 0.01 ? 4.0 : 4.0 * (1.0 - transitionProgress)
        if gap > 0.1 {
            path.setLineDash([6, gap], count: 2, phase: 0)
        }

        let e: CGFloat = 1.0
        // 실제 영역 가장자리만 그리기 (모니터 경계에서는 그리지 않음)
        if abs(cutout.minY - regionLocal.minY) < e {
            path.move(to: NSPoint(x: cutout.minX, y: cutout.minY))
            path.line(to: NSPoint(x: cutout.maxX, y: cutout.minY))
        }
        if abs(cutout.maxY - regionLocal.maxY) < e {
            path.move(to: NSPoint(x: cutout.minX, y: cutout.maxY))
            path.line(to: NSPoint(x: cutout.maxX, y: cutout.maxY))
        }
        if abs(cutout.minX - regionLocal.minX) < e {
            path.move(to: NSPoint(x: cutout.minX, y: cutout.minY))
            path.line(to: NSPoint(x: cutout.minX, y: cutout.maxY))
        }
        if abs(cutout.maxX - regionLocal.maxX) < e {
            path.move(to: NSPoint(x: cutout.maxX, y: cutout.minY))
            path.line(to: NSPoint(x: cutout.maxX, y: cutout.maxY))
        }
        path.stroke()
    }

    private func drawRegionHandles(regionLocal: NSRect) {
        let size = Self.handleSize
        let halfSize = size / 2
        let centers: [NSPoint] = [
            NSPoint(x: regionLocal.minX, y: regionLocal.maxY),
            NSPoint(x: regionLocal.maxX, y: regionLocal.maxY),
            NSPoint(x: regionLocal.minX, y: regionLocal.minY),
            NSPoint(x: regionLocal.maxX, y: regionLocal.minY),
            NSPoint(x: regionLocal.midX, y: regionLocal.maxY),
            NSPoint(x: regionLocal.midX, y: regionLocal.minY),
            NSPoint(x: regionLocal.minX, y: regionLocal.midY),
            NSPoint(x: regionLocal.maxX, y: regionLocal.midY),
        ]
        for center in centers {
            let handleRect = NSRect(x: center.x - halfSize, y: center.y - halfSize, width: size, height: size)
            guard handleRect.intersects(bounds) else { continue }
            NSGraphicsContext.saveGraphicsState()
            Self.handleShadow.set()
            AppColors.handleFill.setFill()
            NSBezierPath(ovalIn: handleRect).fill()
            NSGraphicsContext.restoreGraphicsState()
        }
    }

    private func drawSizeBadge(for rect: NSRect) {
        let width = Int(rect.width)
        let height = Int(rect.height)
        let text = "\(width) \u{00D7} \(height) px"
        let textSize = (text as NSString).size(withAttributes: Self.badgeAttributes)
        let badgePadding: CGFloat = 6
        let badgeWidth = textSize.width + badgePadding * 2
        let badgeHeight = textSize.height + badgePadding
        let badgeX = rect.midX - badgeWidth / 2
        let badgeY = rect.minY - badgeHeight - 4
        let badgeRect = NSRect(x: badgeX, y: badgeY, width: badgeWidth, height: badgeHeight)
        guard badgeRect.intersects(bounds) else { return }
        AppColors.badgeBackground.setFill()
        NSBezierPath(roundedRect: badgeRect, xRadius: 4, yRadius: 4).fill()
        let textX = badgeRect.origin.x + badgePadding
        let textY = badgeRect.origin.y + (badgeHeight - textSize.height) / 2
        (text as NSString).draw(at: NSPoint(x: textX, y: textY), withAttributes: Self.badgeAttributes)
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        guard cutoutRect == nil else { return }
        let point = convert(event.locationInWindow, from: nil)
        startPoint = point
        currentRect = nil
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard cutoutRect == nil else { return }
        var current = convert(event.locationInWindow, from: nil)
        current.x = max(0, min(current.x, bounds.width))
        current.y = max(0, min(current.y, bounds.height))
        guard let start = startPoint else { return }
        let x = min(start.x, current.x)
        let y = min(start.y, current.y)
        let w = abs(current.x - start.x)
        let h = abs(current.y - start.y)
        currentRect = NSRect(x: x, y: y, width: w, height: h)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard cutoutRect == nil else { return }
        guard let rect = currentRect else {
            startPoint = nil
            return
        }
        guard rect.width >= Self.minRegionSize, rect.height >= Self.minRegionSize else {
            startPoint = nil
            currentRect = nil
            needsDisplay = true
            return
        }
        let screenHeight = window?.screen?.frame.height ?? rect.maxY
        let cgRect = CoordinateUtils.appKitToCG(rect, screenHeight: screenHeight)
        onRegionReady?(cgRect)
    }

    // MARK: - Cutout

    func updateCutout(globalRect: CGRect?) {
        guard let globalRect, let windowFrame = window?.frame else {
            regionLocalRect = nil
            cutoutRect = nil
            needsDisplay = true
            return
        }
        let localRect = NSRect(
            x: globalRect.origin.x - windowFrame.origin.x,
            y: globalRect.origin.y - windowFrame.origin.y,
            width: globalRect.width,
            height: globalRect.height
        )
        regionLocalRect = localRect
        let intersection = localRect.intersection(bounds)
        cutoutRect = intersection.isEmpty ? nil : intersection
        needsDisplay = true
    }

    // MARK: - Reset

    func resetToDragging() {
        currentRect = nil
        cutoutRect = nil
        regionLocalRect = nil
        transitionProgress = 0
        startPoint = nil
        needsDisplay = true
    }
}
