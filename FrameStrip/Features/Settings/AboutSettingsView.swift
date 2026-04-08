import SwiftUI

struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: SettingsConfig.aboutIconSize, height: SettingsConfig.aboutIconSize)

            VStack(spacing: 4) {
                Text(appName)
                    .font(.title2.weight(.semibold))
                Text(String(localized: "Show UI motion to AI instead of describing it."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                GridRow {
                    Text("Version")
                        .foregroundStyle(.secondary)
                    Text(version)
                }
                GridRow {
                    Text("Build")
                        .foregroundStyle(.secondary)
                    Text(build)
                }
            }
            .font(.body)

            HStack(spacing: 12) {
                if let url = SettingsConfig.githubURL {
                    Link(destination: url) {
                        Text("GitHub")
                            .frame(minWidth: 60)
                    }
                    .buttonStyle(.bordered)
                }

                if let url = SettingsConfig.licenseURL {
                    Link(destination: url) {
                        Text(SettingsConfig.licenseName)
                            .frame(minWidth: 60)
                    }
                    .buttonStyle(.bordered)
                }
            }

            Text(SettingsConfig.copyright)
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var appName: String {
        Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "FrameStrip"
    }

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
