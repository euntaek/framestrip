import SwiftUI
import AppKit

struct PromptSettingsView: View {
    @Bindable private var settings = SettingsManager.shared

    private struct TemplateVariable: Identifiable {
        let id: String
        let placeholder: String
        let description: String

        init(_ name: String, _ description: String) {
            self.id = name
            self.placeholder = "{{\(name)}}"
            self.description = description
        }
    }

    private static let variables: [TemplateVariable] = [
        TemplateVariable("path", String(localized: "Saved frame folder path (e.g. ~/framestrip/session_001)")),
        TemplateVariable("frameCount", String(localized: "Total number of captured frames")),
        TemplateVariable("skippedCount", String(localized: "Frames skipped by change detection")),
        TemplateVariable("interval", String(localized: "Capture interval in seconds (e.g. 1.0)")),
        TemplateVariable("format", String(localized: "Image format: PNG or JPEG")),
        TemplateVariable("changeDetection", String(localized: "Change detection status: on or off")),
        TemplateVariable("duration", String(localized: "Total recording duration (e.g. 00:42)")),
    ]

    @State private var copiedVariableId: String?

    var body: some View {
        Form {
            variablesSection
            templateSection
            previewSection
        }
        .formStyle(.grouped)
    }

    // MARK: - Variables Section

    private var variablesSection: some View {
        Section {
            FlowLayout(spacing: 6) {
                ForEach(Self.variables) { variable in
                    variableChip(variable)
                }
            }

            Text("Use {{variable}} syntax in the template")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        } header: {
            Text("Variables")
        }
    }

    private func variableChip(_ variable: TemplateVariable) -> some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(variable.placeholder, forType: .string)
            copiedVariableId = variable.id
            DispatchQueue.main.asyncAfter(deadline: .now() + SettingsConfig.copiedFeedbackDuration) {
                if copiedVariableId == variable.id {
                    copiedVariableId = nil
                }
            }
        } label: {
            Group {
                if copiedVariableId == variable.id {
                    Text("Copied")
                        .foregroundStyle(.green)
                } else {
                    Text(variable.id)
                }
            }
            .font(.system(.caption2, design: .monospaced))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.primary.opacity(SettingsConfig.chipBackgroundOpacity), in: RoundedRectangle(cornerRadius: SettingsConfig.chipCornerRadius))
        }
        .buttonStyle(.plain)
        .help(variable.description)
        .animation(.easeInOut(duration: SettingsConfig.chipAnimationDuration), value: copiedVariableId)
    }

    // MARK: - Template Section

    private var templateSection: some View {
        Section("Template") {
            VStack(alignment: .leading, spacing: 8) {
                TextEditor(text: Binding(
                    get: { settings.promptTemplate.isEmpty ? PromptGenerator.defaultTemplate : settings.promptTemplate },
                    set: { settings.promptTemplate = $0 }
                ))
                .font(.system(.body, design: .monospaced))
                .frame(height: SettingsConfig.templateEditorHeight)
                .border(Color.secondary.opacity(0.3), width: 1)

                HStack {
                    Spacer()
                    Button(String(localized: "Reset")) {
                        settings.promptTemplate = ""
                    }
                    .disabled(settings.promptTemplate.isEmpty)
                }
            }
        }
    }

    // MARK: - Preview Section

    private static let previewInfo = CompletionInfo(
        frameCount: 24,
        skippedCount: 3,
        interactionEventCount: 0,
        folder: URL(fileURLWithPath: "~/framestrip/session_001"),
        lastThumbnail: nil,
        interval: 1.0,
        changeDetection: true,
        format: "PNG",
        duration: 10
    )

    private var previewSection: some View {
        Section("Preview") {
            let template = settings.promptTemplate.isEmpty ? PromptGenerator.defaultTemplate : settings.promptTemplate
            let rendered = PromptGenerator.generate(template: template, info: Self.previewInfo)

            Text(rendered)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    struct CacheData {
        var size: CGSize
        var positions: [CGPoint]
    }

    func makeCache(subviews: Subviews) -> CacheData {
        CacheData(size: .zero, positions: [])
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout CacheData) -> CGSize {
        cache = computeLayout(proposal: proposal, subviews: subviews)
        return cache.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout CacheData) {
        for (index, position) in cache.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> CacheData {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
        }

        return CacheData(size: CGSize(width: maxX, height: y + rowHeight), positions: positions)
    }
}
