import AppKit
import SwiftUI

class SelectionControlPanel: NSPanel {
    private static let cornerRadius: CGFloat = 14
    private static let resizeAnimationDuration: TimeInterval = 0.12

    private var lastPosition: NSPoint?
    private let contentModel: ControlPanelContentModel
    private var hostingView: NSHostingView<ControlPanelRootView>?
    private let sourceScreen: NSScreen
    private var isDragging = false
    private var dragOffset: NSPoint = .zero

    var onRecord: (() -> Void)?
    var onStop: (() -> Void)?
    var onClose: (() -> Void)?

    init(mode: ControlPanelPhase, below region: CGRect, on screen: NSScreen, appState: AppState? = nil) {
        self.contentModel = ControlPanelContentModel(phase: mode, appState: appState)
        self.sourceScreen = screen

        let panelSize = NSSize(width: 280, height: 44)
        let position = Self.calculatePosition(for: region, panelSize: panelSize, on: screen)

        super.init(
            contentRect: NSRect(origin: position, size: panelSize),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        becomesKeyOnlyIfNeeded = true
        hidesOnDeactivate = false
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)) + 2)
        collectionBehavior = [.canJoinAllSpaces, .stationary]
        isOpaque = false
        hasShadow = false
        backgroundColor = .clear
        isReleasedWhenClosed = false
        isMovableByWindowBackground = false

        setupContentIfNeeded()
        resizeToFitContent()
        lastPosition = position

        NativeMenuTarget.shared.onSettingChanged = { [weak self] in
            self?.resizeToFitContent(animated: true)
        }
    }

    private func setupContentIfNeeded() {
        guard hostingView == nil else { return }

        contentModel.onRecord = { [weak self] in self?.onRecord?() }
        contentModel.onStop = { [weak self] in self?.onStop?() }
        contentModel.onClose = { [weak self] in self?.onClose?() }

        let hostingView = NSHostingView(rootView: ControlPanelRootView(model: contentModel))
        hostingView.frame = NSRect(origin: .zero, size: NSSize(width: 600, height: 100))
        hostingView.layoutSubtreeIfNeeded()

        let effectView = NSVisualEffectView(frame: NSRect(origin: .zero, size: hostingView.fittingSize))
        effectView.material = .popover
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.appearance = NSAppearance(named: .darkAqua)
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = Self.cornerRadius
        effectView.layer?.masksToBounds = true
        effectView.autoresizingMask = [.width, .height]

        let tintView = NSView(frame: effectView.bounds)
        tintView.wantsLayer = true
        tintView.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.03).cgColor
        tintView.autoresizingMask = [.width, .height]
        effectView.addSubview(tintView)

        hostingView.frame = effectView.bounds
        hostingView.autoresizingMask = [.width, .height]
        effectView.addSubview(hostingView)

        contentView = effectView
        self.hostingView = hostingView
    }

    // MARK: - Dynamic Resize

    private func resizeToFitContent(animated: Bool = false) {
        guard let hostingView else { return }

        hostingView.invalidateIntrinsicContentSize()
        hostingView.layoutSubtreeIfNeeded()
        contentView?.layoutSubtreeIfNeeded()

        let size = hostingView.fittingSize
        let oldCenter = NSPoint(x: frame.midX, y: frame.midY)
        let newOrigin = clampToScreen(
            NSPoint(x: oldCenter.x - size.width / 2, y: oldCenter.y - size.height / 2)
        )
        let newFrame = NSRect(origin: newOrigin, size: size)

        if animated && isVisible {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = Self.resizeAnimationDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                self.animator().setFrame(newFrame, display: true)
            }
        } else {
            setFrame(newFrame, display: true)
        }
    }

    deinit {
        NativeMenuTarget.shared.onSettingChanged = nil
    }

    // MARK: - Position

    static func calculatePosition(for region: CGRect, panelSize: NSSize, on screen: NSScreen) -> NSPoint {
        let screenFrame = screen.frame
        let badgeHeight: CGFloat = 24
        let gap: CGFloat = 8

        let regionBottom = screenFrame.origin.y + screenFrame.height - region.maxY
        var x = screenFrame.origin.x + region.origin.x + region.width / 2 - panelSize.width / 2
        var y = regionBottom - badgeHeight - gap - panelSize.height

        if y < screenFrame.origin.y {
            let regionTop = screenFrame.origin.y + screenFrame.height - region.origin.y
            y = regionTop + gap
        }

        x = max(screenFrame.origin.x, min(x, screenFrame.maxX - panelSize.width))
        y = max(screenFrame.origin.y, min(y, screenFrame.maxY - panelSize.height))

        return NSPoint(x: x, y: y)
    }

    private func clampToScreen(_ origin: NSPoint) -> NSPoint {
        let screenFrame = sourceScreen.frame
        let x = max(screenFrame.minX, min(origin.x, screenFrame.maxX - frame.width))
        let y = max(screenFrame.minY, min(origin.y, screenFrame.maxY - frame.height))
        return NSPoint(x: x, y: y)
    }

    // MARK: - Custom Drag

    override func mouseDown(with event: NSEvent) {
        let mouseLocation = NSEvent.mouseLocation
        dragOffset = NSPoint(
            x: mouseLocation.x - frame.origin.x,
            y: mouseLocation.y - frame.origin.y
        )
        isDragging = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }
        let mouseLocation = NSEvent.mouseLocation
        let newOrigin = NSPoint(
            x: mouseLocation.x - dragOffset.x,
            y: mouseLocation.y - dragOffset.y
        )
        setFrameOrigin(clampToScreen(newOrigin))
    }

    override func mouseUp(with event: NSEvent) {
        guard isDragging else { return }
        isDragging = false
        lastPosition = frame.origin
    }

    // MARK: - Show / Switch / Restore

    func showWithFadeIn() {
        alphaValue = 0
        orderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 1
        }
    }

    func switchToRecordingMode(appState: AppState) {
        updateContent(phase: .recording, appState: appState)
    }

    func switchToFinalizingMode(appState: AppState) {
        updateContent(phase: .finalizing, appState: appState)
    }

    private func updateContent(phase newPhase: ControlPanelPhase, appState: AppState?) {
        contentModel.phase = newPhase
        contentModel.appState = appState

        DispatchQueue.main.async { [weak self] in
            self?.resizeToFitContent(animated: true)
        }
    }

    func restoreAtLastPosition() {
        if let pos = lastPosition {
            setFrameOrigin(clampToScreen(pos))
        }
        showWithFadeIn()
    }

    override func close() {
        lastPosition = frame.origin
        super.close()
    }
}
