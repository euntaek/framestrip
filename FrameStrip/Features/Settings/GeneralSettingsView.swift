import SwiftUI

struct GeneralSettingsView: View {
    @Bindable private var settings = SettingsManager.shared
    let appState: AppState
    var onCheckForUpdates: (() -> Void)?
    @State private var showRestartAlert = false

    var body: some View {
        Form {
            if let onCheckForUpdates {
                Section("Updates") {
                    Toggle(String(localized: "Automatically check for updates"), isOn: $settings.automaticallyChecksForUpdates)

                    Button(String(localized: "Check for Updates...")) {
                        onCheckForUpdates()
                    }
                }
            }

            Section("Language") {
                Picker(String(localized: "Language"), selection: $settings.language) {
                    Text(String(localized: "System")).tag(SettingsManager.Language.system)
                    Text("한국어").tag(SettingsManager.Language.ko)
                    Text("English").tag(SettingsManager.Language.en)
                }
                .disabled(appState.status == .recording || appState.status == .finalizing)
                .onChange(of: settings.language) {
                    showRestartAlert = true
                }
            }

            Section("Storage") {
                HStack {
                    Text("Save Folder")
                    Spacer()
                    Text(settings.saveFolderPath)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Button(String(localized: "Change...")) {
                        chooseSaveFolder()
                    }
                }
            }

            Section("Shortcut") {
                ShortcutRecorderRow(settings: settings)
            }
        }
        .formStyle(.grouped)
        .alert(String(localized: "Restart Required"), isPresented: $showRestartAlert) {
            Button(String(localized: "Later"), role: .cancel) { }
            Button(String(localized: "Restart Now")) {
                restartApp()
            }
        } message: {
            Text("Restart the app to apply the language change.")
        }
    }

    private func restartApp() {
        let executablePath = Bundle.main.executablePath!
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = Array(CommandLine.arguments.dropFirst())
        try? process.run()
        NSApplication.shared.terminate(nil)
    }

    private func chooseSaveFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = String(localized: "Select")
        panel.message = String(localized: "Select a folder to save captured images")

        if panel.runModal() == .OK, let url = panel.url {
            settings.saveFolderPath = url.path
        }
    }
}
