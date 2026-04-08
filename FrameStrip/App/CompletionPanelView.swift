import SwiftUI

struct CompletionPanelView: View {
    fileprivate enum Style {
        static let hoverDuration: TimeInterval = 0.2
        static let interactiveDuration: TimeInterval = 0.15
        static let dragThreshold: CGFloat = 60
        static let buttonWidth: CGFloat = 130
        static let buttonHeight: CGFloat = 32
        static let buttonCornerRadius: CGFloat = 8
        static let closeButtonSize: CGFloat = 20
        static let closeFontSize: CGFloat = 9
        static let badgeFontSize: CGFloat = 11
        static let buttonFontSize: CGFloat = 13
    }

    let info: CompletionInfo
    var onCopyPrompt: () -> Void
    var onCopyPath: () -> Void
    var onOpenFinder: () -> Void
    var onDismiss: () -> Void

    @State private var isHovering = false
    @State private var dragOffset: CGFloat = 0

    private let maxWidth = CompletionPanelWindow.Layout.maxWidth
    private let maxHeight = CompletionPanelWindow.Layout.maxHeight
    private let cornerRadius = CompletionPanelWindow.Layout.cornerRadius

    private var thumbnailSize: CGSize {
        guard let image = info.lastThumbnail else { return CGSize(width: maxWidth, height: maxHeight) }
        let imageWidth = image.size.width
        let imageHeight = image.size.height
        guard imageWidth > 0, imageHeight > 0 else { return CGSize(width: maxWidth, height: maxHeight) }

        let scale = min(maxWidth / imageWidth, maxHeight / imageHeight)
        return CGSize(width: round(imageWidth * scale), height: round(imageHeight * scale))
    }

    var body: some View {
        VStack {
            Spacer(minLength: 0)
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                panelContent
            }
        }
        .frame(width: maxWidth, height: maxHeight)
    }

    private var panelContent: some View {
        ZStack {
            if let thumbnail = info.lastThumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: isHovering ? .fill : .fit)
                    .clipped()
            }

            if isHovering {
                hoverOverlay
                    .transition(.opacity)
            }
        }
        .frame(
            width: isHovering ? maxWidth : thumbnailSize.width,
            height: isHovering ? maxHeight : thumbnailSize.height
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(.white.opacity(isHovering ? 0 : 0.5), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        .offset(x: dragOffset)
        .opacity(1 - Double(dragOffset / maxWidth))
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.width > 0 {
                        dragOffset = value.translation.width
                    }
                }
                .onEnded { value in
                    if value.translation.width > Style.dragThreshold {
                        withAnimation(.easeIn(duration: Style.hoverDuration)) {
                            dragOffset = maxWidth
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + Style.hoverDuration) {
                            onDismiss()
                        }
                    } else {
                        withAnimation(.easeOut(duration: Style.hoverDuration)) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: Style.hoverDuration)) {
                isHovering = hovering
            }
        }
    }

    // MARK: - Hover Overlay

    private var hoverOverlay: some View {
        ZStack {
            VisualEffectView(material: .hudWindow)

            VStack(spacing: 0) {
                HStack {
                    Text(badgeText)
                        .font(.system(size: Style.badgeFontSize, weight: .regular))
                        .foregroundStyle(.white.opacity(0.6))

                    Spacer()

                    CloseButton(action: onDismiss)
                }
                .padding(.horizontal, 10)
                .padding(.top, 10)

                Spacer()

                VStack(spacing: 8) {
                    OverlayButton(title: String(localized: "Copy Prompt"), action: onCopyPrompt)
                    OverlayButton(title: String(localized: "Copy Path"), action: onCopyPath)
                    OverlayButton(title: String(localized: "Open in Finder"), action: onOpenFinder)
                }

                Spacer()
            }
        }
        .frame(width: maxWidth, height: maxHeight)
    }

    private var badgeText: String {
        var parts: [String] = []

        if info.skippedCount > 0 {
            parts.append("\(info.frameCount)f · \(info.skippedCount) \(String(localized: "skipped"))")
        } else {
            parts.append(String(localized: "\(info.frameCount) frames"))
        }

        if info.interactionEventCount > 0 {
            parts.append(String(localized: "\(info.interactionEventCount) interactions"))
        }

        return parts.joined(separator: " · ")
    }
}

// MARK: - Close Button

private struct CloseButton: View {
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: CompletionPanelView.Style.closeFontSize, weight: .bold))
                .foregroundStyle(isHovering ? .white : .white.opacity(0.6))
                .frame(width: CompletionPanelView.Style.closeButtonSize, height: CompletionPanelView.Style.closeButtonSize)
                .background(isHovering ? .white.opacity(0.25) : .white.opacity(0.1))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: CompletionPanelView.Style.interactiveDuration)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Action Button

private struct OverlayButton: View {
    let title: String
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: CompletionPanelView.Style.buttonFontSize, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: CompletionPanelView.Style.buttonWidth, height: CompletionPanelView.Style.buttonHeight)
                .background(isHovering ? .white.opacity(0.25) : .white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: CompletionPanelView.Style.buttonCornerRadius))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: CompletionPanelView.Style.interactiveDuration)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - NSVisualEffectView Wrapper

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.state = .active
        view.blendingMode = .withinWindow
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
