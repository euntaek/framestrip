import SwiftUI
import AppKit

// MARK: - Native Menu Helper

final class NativeMenuTarget: NSObject {
    static let shared = NativeMenuTarget()
    private var actions: [Int: () -> Void] = [:]
    private var nextTag = 0

    /// 메뉴 옵션 선택 후 패널 리사이즈를 위한 콜백
    var onSettingChanged: (() -> Void)?

    func addAction(_ action: @escaping () -> Void) -> Int {
        let tag = nextTag
        nextTag += 1
        actions[tag] = action
        return tag
    }

    @objc func performAction(_ sender: NSMenuItem) {
        actions[sender.tag]?()
        cleanup()
        onSettingChanged?()
    }

    func cleanup() {
        actions.removeAll()
        nextTag = 0
    }
}

// MARK: - PanelActionButtonStyle

struct PanelActionButtonStyle: ButtonStyle {
    let backgroundColor: Color
    var minWidth: CGFloat? = nil
    var isEnabled = true
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .frame(minWidth: minWidth)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(isEnabled ? (configuration.isPressed ? 0.25 : (isHovered ? 0.15 : 0)) : 0))
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .scaleEffect(isEnabled && configuration.isPressed ? 0.97 : 1.0)
            .opacity(isEnabled ? 1.0 : 0.5)
            .onHover { hovering in
                guard isEnabled else {
                    isHovered = false
                    return
                }
                withAnimation(.easeInOut(duration: 0.15)) { isHovered = hovering }
            }
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - CircleCloseButtonStyle

struct CircleCloseButtonStyle: ButtonStyle {
    var isEnabled = true
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 16, height: 16)
            .background(
                Circle()
                    .fill(Color.white.opacity(isEnabled ? (configuration.isPressed ? 0.3 : (isHovered ? 0.25 : 0.1)) : 0.08))
            )
            .clipShape(Circle())
            .opacity(isEnabled ? 1.0 : 0.5)
            .onHover { hovering in
                guard isEnabled else {
                    isHovered = false
                    return
                }
                withAnimation(.easeInOut(duration: 0.15)) { isHovered = hovering }
            }
    }
}

// MARK: - ControlPanelRootView

struct ControlPanelRootView: View {
    let model: ControlPanelContentModel

    @State private var dotOpacity: Double = 1.0

    private var state: ControlPanelViewState {
        ControlPanelViewState.make(for: model.phase)
    }

    private var actionBackgroundColor: Color {
        switch model.phase {
        case .adjusting:
            Color(nsColor: AppColors.recordButton)
        case .recording:
            Color(nsColor: AppColors.recording)
        case .finalizing:
            Color(nsColor: AppColors.finalizingActionBackground)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            Button(action: model.onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .buttonStyle(CircleCloseButtonStyle(isEnabled: state.isCloseEnabled))
            .disabled(!state.isCloseEnabled)
            .padding(.leading, 14)
            .padding(.trailing, 14)

            separator

            Group {
                if state.showsAdjustingChips {
                    HStack(spacing: 10) {
                        IntervalChip()
                        ChangeDetectionChip()
                        InteractionCaptureChip()
                        LimitChip()
                    }
                    .padding(.horizontal, 12)
                } else if let appState = model.appState, state.showsRecordingStatus {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(nsColor: AppColors.recording))
                            .frame(width: 8, height: 8)
                            .opacity(state.isRecordingDotPulsing ? dotOpacity : state.recordingDotOpacity)

                        Text(ElapsedTimeFormatter.formatTime(appState.elapsedTime))
                            .font(.system(size: 13))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 12)
                }
            }

            separator

            if state.showsRecordingStatus, let appState = model.appState {
                Text("\(appState.frameCount) frames")
                    .font(.system(size: 13))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .frame(minWidth: 80, alignment: .center)
                    .padding(.horizontal, 12)

                separator
            }

            Button(action: actionHandler) {
                ZStack {
                    if let actionTitle = state.actionTitle {
                        Text(actionTitle)
                            .foregroundStyle(.white)
                    }

                    if state.showsActionSpinner {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    }
                }
            }
            .buttonStyle(
                PanelActionButtonStyle(
                    backgroundColor: actionBackgroundColor,
                    minWidth: state.actionMinWidth,
                    isEnabled: state.isActionEnabled
                )
            )
            .disabled(!state.isActionEnabled)
            .padding(.leading, 10)
            .padding(.trailing, 6)
        }
        .padding(.vertical, 6)
        .fixedSize()
        .onAppear {
            updateRecordingIndicator(for: model.phase)
        }
        .onChange(of: model.phase) { _, newPhase in
            updateRecordingIndicator(for: newPhase)
        }
    }

    private var separator: some View {
        Color(nsColor: AppColors.panelSeparator)
            .frame(width: 1, height: 22)
    }

    private func actionHandler() {
        switch model.phase {
        case .adjusting:
            model.onRecord()
        case .recording:
            model.onStop()
        case .finalizing:
            break
        }
    }

    private func updateRecordingIndicator(for phase: ControlPanelPhase) {
        let state = ControlPanelViewState.make(for: phase)
        dotOpacity = 1.0

        guard state.showsRecordingStatus else { return }

        if state.isRecordingDotPulsing {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                dotOpacity = 0.3
            }
        } else {
            dotOpacity = state.recordingDotOpacity
        }
    }
}

// MARK: - IntervalChip

struct IntervalChip: View {
    let settings = SettingsManager.shared

    @State private var isHovered = false

    private let options: [Double] = [0.1, 0.2, 0.5, 1.0, 2.0, 3.0, 5.0, 10.0]

    var body: some View {
        Button {
            showIntervalMenu()
        } label: {
            Text(formatInterval(settings.captureInterval))
                .font(.system(size: 13))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(isHovered ? 0.12 : 0))
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { isHovered = hovering }
        }
    }

    private func showIntervalMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let target = NativeMenuTarget.shared
        target.cleanup()

        for option in options {
            let item = NSMenuItem(
                title: formatInterval(option),
                action: #selector(NativeMenuTarget.performAction(_:)),
                keyEquivalent: ""
            )
            item.target = target
            item.state = (abs(settings.captureInterval - option) < 0.01) ? .on : .off
            let opt = option
            item.tag = target.addAction { [weak settings] in
                settings?.captureInterval = opt
            }
            menu.addItem(item)
        }

        if !options.contains(where: { abs($0 - settings.captureInterval) < 0.01 }) {
            menu.addItem(.separator())
            let item = NSMenuItem(
                title: "\(formatInterval(settings.captureInterval)) (" + String(localized: "custom") + ")",
                action: nil,
                keyEquivalent: ""
            )
            item.state = .on
            item.isEnabled = false
            menu.addItem(item)
        }

        showMenuAtMouse(menu)
    }

    private func formatInterval(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0fs", value)
        }
        return String(format: "%.1fs", value)
    }
}

// MARK: - ChangeDetectionChip

struct ChangeDetectionChip: View {
    let settings = SettingsManager.shared

    @State private var isHovered = false

    var body: some View {
        let isOn = settings.changeDetectionEnabled

        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                settings.changeDetectionEnabled.toggle()
            }
        } label: {
            Text("\u{25B3}")
                .font(.system(size: 13))
                .foregroundStyle(
                    Color(nsColor: isOn ? AppColors.changeDetectionOnText : AppColors.changeDetectionOffText)
                )
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(isHovered ? 0.12 : 0))
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { isHovered = hovering }
        }
        .chipTooltip(String(localized: "Change detection"), isOn: isOn)
        .animation(.easeInOut(duration: 0.2), value: isOn)
    }
}

// MARK: - InteractionCaptureChip

struct InteractionCaptureChip: View {
    let settings = SettingsManager.shared

    @State private var isHovered = false

    var body: some View {
        let isOn = settings.interactionCapture

        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                settings.interactionCapture.toggle()
            }
        } label: {
            Image(systemName: "cursorarrow.click.2")
                .font(.system(size: 13))
                .foregroundStyle(
                    Color(nsColor: isOn ? AppColors.changeDetectionOnText : AppColors.changeDetectionOffText)
                )
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(isHovered ? 0.12 : 0))
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { isHovered = hovering }
        }
        .chipTooltip(String(localized: "Interaction Capture"), isOn: isOn)
        .animation(.easeInOut(duration: 0.2), value: isOn)
    }
}

// MARK: - LimitChip

struct LimitChip: View {
    let settings = SettingsManager.shared

    @State private var isHovered = false

    private let frameOptions: [Int] = [0, 10, 50, 100, 500, 1000, 5000, 10000]
    private let durationOptions: [Int] = [0, 10, 30, 60, 120, 300, 600, 1800, 3600]

    var body: some View {
        Button {
            showLimitMenu()
        } label: {
            Text(chipLabel)
                .font(.system(size: 13))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(isHovered ? 0.12 : 0))
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { isHovered = hovering }
        }
    }

    private func showLimitMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let target = NativeMenuTarget.shared
        target.cleanup()

        // Frame section header
        let frameHeader = NSMenuItem(title: String(localized: "Frames"), action: nil, keyEquivalent: "")
        frameHeader.isEnabled = false
        frameHeader.attributedTitle = NSAttributedString(
            string: String(localized: "Frames"),
            attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .medium),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )
        menu.addItem(frameHeader)

        for option in frameOptions {
            let item = NSMenuItem(
                title: frameLabel(option),
                action: #selector(NativeMenuTarget.performAction(_:)),
                keyEquivalent: ""
            )
            item.target = target
            item.state = settings.maxFrames == option ? .on : .off
            let opt = option
            item.tag = target.addAction { [weak settings] in
                settings?.maxFrames = opt
            }
            menu.addItem(item)
        }

        if !frameOptions.contains(settings.maxFrames) {
            let item = NSMenuItem(
                title: "\(settings.maxFrames) (" + String(localized: "custom") + ")",
                action: nil,
                keyEquivalent: ""
            )
            item.state = .on
            item.isEnabled = false
            menu.addItem(item)
        }

        menu.addItem(.separator())

        // Duration section header
        let durationHeader = NSMenuItem(title: String(localized: "Duration"), action: nil, keyEquivalent: "")
        durationHeader.isEnabled = false
        durationHeader.attributedTitle = NSAttributedString(
            string: String(localized: "Duration"),
            attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .medium),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )
        menu.addItem(durationHeader)

        for option in durationOptions {
            let item = NSMenuItem(
                title: durationLabel(option),
                action: #selector(NativeMenuTarget.performAction(_:)),
                keyEquivalent: ""
            )
            item.target = target
            item.state = settings.maxDuration == option ? .on : .off
            let opt = option
            item.tag = target.addAction { [weak settings] in
                settings?.maxDuration = opt
            }
            menu.addItem(item)
        }

        if !durationOptions.contains(settings.maxDuration) {
            let item = NSMenuItem(
                title: "\(formatDuration(settings.maxDuration)) (" + String(localized: "custom") + ")",
                action: nil,
                keyEquivalent: ""
            )
            item.state = .on
            item.isEnabled = false
            menu.addItem(item)
        }

        showMenuAtMouse(menu)
    }

    private var chipLabel: String {
        let hasFrameLimit = settings.maxFrames > 0
        let hasDurationLimit = settings.maxDuration > 0

        if !hasFrameLimit && !hasDurationLimit {
            return "\u{221E}"
        }

        var parts: [String] = []
        if hasFrameLimit {
            parts.append("\(settings.maxFrames)f")
        }
        if hasDurationLimit {
            parts.append(formatDuration(settings.maxDuration))
        }
        return parts.joined(separator: "/")
    }

    private func frameLabel(_ value: Int) -> String {
        value == 0 ? "∞" : "\(value)"
    }

    private func durationLabel(_ value: Int) -> String {
        ElapsedTimeFormatter.durationLabel(value)
    }

    private func formatDuration(_ seconds: Int) -> String {
        ElapsedTimeFormatter.durationLabel(seconds)
    }
}

// MARK: - ChipTooltipWindow

private enum ChipTooltipStyle {
    static let fontSize: CGFloat = 12
    static let paddingH: CGFloat = 8
    static let paddingV: CGFloat = 4
    static let cornerRadius: CGFloat = 6
    static let backgroundOpacity: Double = 0.85
    static let gap: CGFloat = 4
    static let fadeInDuration: TimeInterval = 0.08
}

@MainActor final class ChipTooltipWindow: NSWindow {
    static let shared = ChipTooltipWindow()

    private var hostingView: NSHostingView<TooltipContentView>?
    private var lastText: String?

    private init() {
        super.init(
            contentRect: .zero,
            styleMask: .borderless,
            backing: .buffered,
            defer: true
        )
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)) + 2)
        collectionBehavior = [.canJoinAllSpaces, .stationary]
        isOpaque = false
        hasShadow = false
        backgroundColor = .clear
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
    }

    func show(text: String, chipFrame: NSRect, screen: NSScreen) {
        let hosting: NSHostingView<TooltipContentView>
        if let existing = hostingView {
            if lastText != text {
                existing.rootView = TooltipContentView(text: text)
            }
            hosting = existing
        } else {
            hosting = NSHostingView(rootView: TooltipContentView(text: text))
            contentView = hosting
            hostingView = hosting
        }
        lastText = text

        hosting.invalidateIntrinsicContentSize()
        hosting.layoutSubtreeIfNeeded()
        let size = hosting.fittingSize

        let screenFrame = screen.visibleFrame

        let yAbove = chipFrame.maxY + ChipTooltipStyle.gap
        let y = (yAbove + size.height <= screenFrame.maxY)
            ? yAbove
            : chipFrame.minY - ChipTooltipStyle.gap - size.height

        let x = max(screenFrame.minX, min(chipFrame.midX - size.width / 2, screenFrame.maxX - size.width))

        setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)

        alphaValue = 0
        orderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = ChipTooltipStyle.fadeInDuration
            self.animator().alphaValue = 1
        }
    }

    func hide() {
        orderOut(nil)
        alphaValue = 0
    }
}

struct TooltipContentView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: ChipTooltipStyle.fontSize))
            .foregroundStyle(.white)
            .padding(.horizontal, ChipTooltipStyle.paddingH)
            .padding(.vertical, ChipTooltipStyle.paddingV)
            .background(
                RoundedRectangle(cornerRadius: ChipTooltipStyle.cornerRadius)
                    .fill(Color.black.opacity(ChipTooltipStyle.backgroundOpacity))
            )
            .fixedSize()
    }
}

private struct TooltipAnchor: NSViewRepresentable {
    @Binding var view: NSView?

    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async { view = v }
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct ChipTooltip: ViewModifier {
    let text: String
    let isOn: Bool
    @State private var anchorView: NSView?
    @State private var showTask: Task<Void, Never>?

    private func cancelAndHide() {
        showTask?.cancel()
        showTask = nil
        ChipTooltipWindow.shared.hide()
    }

    func body(content: Content) -> some View {
        content
            .background(TooltipAnchor(view: $anchorView))
            .onHover { hovering in
                if hovering {
                    showTask?.cancel()
                    showTask = Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(300))
                        guard !Task.isCancelled else { return }
                        guard let anchor = anchorView, let window = anchor.window,
                              let screen = window.screen else { return }
                        let frameInWindow = anchor.convert(anchor.bounds, to: nil)
                        let chipFrame = window.convertToScreen(frameInWindow)
                        ChipTooltipWindow.shared.show(text: text, chipFrame: chipFrame, screen: screen)
                    }
                } else {
                    cancelAndHide()
                }
            }
            .onDisappear { cancelAndHide() }
            .accessibilityLabel(text)
            .accessibilityValue(isOn ? String(localized: "On") : String(localized: "Off"))
    }
}

extension View {
    func chipTooltip(_ text: String, isOn: Bool) -> some View {
        modifier(ChipTooltip(text: text, isOn: isOn))
    }
}

// MARK: - Menu Presentation Helper

private func showMenuAtMouse(_ menu: NSMenu) {
    guard let event = NSApp.currentEvent else { return }

    if let window = event.window, let contentView = window.contentView {
        let locationInWindow = event.locationInWindow
        let locationInView = contentView.convert(locationInWindow, from: nil)
        menu.popUp(positioning: nil, at: locationInView, in: contentView)
    } else {
        let mouseLocation = NSEvent.mouseLocation
        menu.popUp(positioning: nil, at: mouseLocation, in: nil)
    }
}
