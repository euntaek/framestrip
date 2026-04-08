import AppKit
import SwiftUI

class CompletionPanelWindow: NSPanel {
    enum Layout {
        static let maxWidth: CGFloat = 240
        static let maxHeight: CGFloat = 200
        static let cornerRadius: CGFloat = 12
        static let screenMargin: CGFloat = 16
        static let animationDuration: TimeInterval = 0.35
        static let autoDismissDelay: TimeInterval = 5.0
    }

    private var dismissTimer: Timer?
    private var trackingArea: NSTrackingArea?
    private var isDismissing = false
    var onDismissed: (() -> Void)?

    init(info: CompletionInfo) {
        // 윈도우를 max 크기로 생성 (투명 영역 포함)
        let maxSize = NSSize(width: Layout.maxWidth, height: Layout.maxHeight)

        super.init(
            contentRect: NSRect(origin: .zero, size: maxSize),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary]
        isOpaque = false
        hasShadow = false
        backgroundColor = .clear
        isReleasedWhenClosed = false
        isMovableByWindowBackground = false

        let panelView = CompletionPanelView(
            info: info,
            onCopyPrompt: { [weak self] in
                self?.copyPrompt(info)
            },
            onCopyPath: { [weak self] in
                self?.copyPath(info.folder)
            },
            onOpenFinder: { [weak self] in
                self?.openFinder(info.folder)
            },
            onDismiss: { [weak self] in
                self?.dismiss()
            }
        )
        let hostingView = NSHostingView(rootView: panelView)
        hostingView.frame = NSRect(origin: .zero, size: maxSize)
        hostingView.autoresizingMask = [.width, .height]

        let containerView = NSView(frame: NSRect(origin: .zero, size: maxSize))
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = Layout.cornerRadius
        containerView.layer?.masksToBounds = true
        containerView.addSubview(hostingView)

        contentView = containerView
        setContentSize(maxSize)

        positionBottomRight()
    }

    // MARK: - Positioning

    private func positionBottomRight() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.maxX - frame.width - Layout.screenMargin
        let y = screenFrame.minY + Layout.screenMargin
        setFrameOrigin(NSPoint(x: x, y: y))
    }

    // MARK: - Auto Dismiss

    func startAutoDismiss() {
        restartDismissTimer()
        setupTrackingAreaIfNeeded()
    }

    private func restartDismissTimer() {
        dismissTimer?.invalidate()
        dismissTimer = Timer(timeInterval: Layout.autoDismissDelay, repeats: false) { [weak self] _ in
            self?.dismiss()
        }
        RunLoop.current.add(dismissTimer!, forMode: .common)
    }

    private func setupTrackingAreaIfNeeded() {
        guard trackingArea == nil else { return }
        let area = NSTrackingArea(
            rect: contentView?.bounds ?? .zero,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        contentView?.addTrackingArea(area)
        trackingArea = area
    }

    private func cleanupTrackingArea() {
        if let area = trackingArea {
            contentView?.removeTrackingArea(area)
            trackingArea = nil
        }
    }

    override func mouseEntered(with event: NSEvent) {
        dismissTimer?.invalidate()
        dismissTimer = nil
    }

    override func mouseExited(with event: NSEvent) {
        restartDismissTimer()
    }

    // MARK: - Actions

    private func copyPrompt(_ info: CompletionInfo) {
        let template = SettingsManager.shared.promptTemplate
        let prompt = PromptGenerator.generate(template: template, info: info)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(prompt, forType: .string)
        dismiss()
    }

    private func copyPath(_ folder: URL?) {
        guard let path = folder?.path else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(path, forType: .string)
        dismiss()
    }

    private func openFinder(_ folder: URL?) {
        guard let folder else { return }
        NSWorkspace.shared.open(folder)
        dismiss()
    }

    func dismiss() {
        guard !isDismissing else { return }
        isDismissing = true
        dismissTimer?.invalidate()
        dismissTimer = nil
        cleanupTrackingArea()
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Layout.animationDuration
            self.animator().alphaValue = 0
        }, completionHandler: {
            self.close()
            self.onDismissed?()
        })
    }

    func show() {
        alphaValue = 0
        orderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Layout.animationDuration
            self.animator().alphaValue = 1
        }
        startAutoDismiss()
    }
}
