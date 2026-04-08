import SwiftUI
import Carbon

extension Notification.Name {
    static let hotkeyDidChange = Notification.Name("hotkeyDidChange")
}

enum SettingsCategory: String, CaseIterable, Identifiable {
    case capture
    case general
    case prompt
    case about

    var id: String { rawValue }

    var label: String {
        switch self {
        case .capture: String(localized: "Capture")
        case .general: String(localized: "General")
        case .prompt: String(localized: "Prompt")
        case .about: String(localized: "About")
        }
    }

    var icon: String {
        switch self {
        case .capture: "camera"
        case .general: "gearshape"
        case .prompt: "text.document"
        case .about: "info.circle"
        }
    }
}

struct SettingsView: View {
    let appState: AppState
    @State private var selectedCategory: SettingsCategory = .capture

    var body: some View {
        NavigationSplitView {
            List(SettingsCategory.allCases, selection: $selectedCategory) { category in
                HStack(spacing: 10) {
                    Image(systemName: category.icon)
                        .font(.system(size: SettingsConfig.iconFontSize, weight: .medium))
                        .foregroundStyle(SettingsConfig.iconForeground)
                        .frame(width: SettingsConfig.iconSize, height: SettingsConfig.iconSize)
                        .background(
                            LinearGradient(
                                colors: [SettingsConfig.iconGradientTop, SettingsConfig.iconGradientBottom],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            in: RoundedRectangle(cornerRadius: SettingsConfig.iconCornerRadius, style: .continuous)
                        )
                        .shadow(color: .black.opacity(SettingsConfig.iconShadowOpacity), radius: SettingsConfig.iconShadowRadius, y: SettingsConfig.iconShadowRadius)
                    Text(category.label)
                }
                .padding(.vertical, 2)
                .tag(category)
            }
            .navigationSplitViewColumnWidth(SettingsConfig.sidebarWidth)
        } detail: {
            switch selectedCategory {
            case .capture:
                CaptureSettingsView()
            case .general:
                GeneralSettingsView(appState: appState)
            case .prompt:
                PromptSettingsView()
            case .about:
                AboutSettingsView()
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

// MARK: - Shortcut Recorder

struct ShortcutRecorderRow: View {
    @Bindable var settings: SettingsManager
    @State private var isRecording = false
    @State private var eventMonitor: Any?

    var body: some View {
        HStack {
            Text("Start/Stop Recording Shortcut")
            Spacer()
            Button(action: { toggleRecording() }) {
                Text(isRecording ? String(localized: "Press a key...") : shortcutDisplayString)
                    .foregroundStyle(isRecording ? .red : .primary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(.quaternary)
            .cornerRadius(4)
        }
        .onDisappear {
            stopRecording()
        }
    }

    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == KeyCodes.escape {
                stopRecording()
                return nil
            }

            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let hasModifier = !modifiers.intersection([.command, .option, .control, .shift]).isEmpty

            if hasModifier {
                settings.hotkeyKeyCode = UInt32(event.keyCode)
                settings.hotkeyModifiers = UInt32(modifiers.rawValue)
                stopRecording()
                NotificationCenter.default.post(name: .hotkeyDidChange, object: nil)
            }
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private var shortcutDisplayString: String {
        let modifiers = NSEvent.ModifierFlags(rawValue: UInt(settings.hotkeyModifiers))
        var parts: [String] = []

        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }

        let keyName = keyCodeToString(UInt16(settings.hotkeyKeyCode))
        parts.append(keyName)

        return parts.joined()
    }

    private func keyCodeToString(_ keyCode: UInt16) -> String {
        KeyCodes.displayNames[keyCode] ?? "Key\(keyCode)"
    }
}
