import SwiftUI

struct CaptureSettingsView: View {
    @Bindable private var settings = SettingsManager.shared

    private static let intervalOptions: [Double] = [0.1, 0.2, 0.5, 1.0, 2.0, 3.0, 5.0, 10.0]
    private static let qualityOptions: [Double] = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]
    private static let frameOptions: [Int] = [0, 10, 50, 100, 500, 1000, 5000, 10000]
    private static let durationOptions: [Int] = [0, 10, 30, 60, 120, 300, 600, 1800, 3600]

    var body: some View {
        Form {
            Section("Interval") {
                Picker("Capture Interval", selection: $settings.captureInterval) {
                    ForEach(Self.intervalOptions, id: \.self) { value in
                        Text(String(format: "%.1f", value) + String(localized: "s", comment: "Second unit abbreviation")).tag(value)
                    }
                }

                Picker("Image Format", selection: $settings.imageFormat) {
                    Text("PNG").tag(SettingsManager.ImageFormat.png)
                    Text("JPEG").tag(SettingsManager.ImageFormat.jpeg)
                }

                if settings.imageFormat == .jpeg {
                    Picker("JPEG Quality", selection: $settings.jpegQuality) {
                        ForEach(Self.qualityOptions, id: \.self) { value in
                            Text("\(Int(value * 100))%").tag(value)
                        }
                    }
                }
            }

            Section("Change Detection") {
                Toggle("Change Detection", isOn: $settings.changeDetectionEnabled)
                Text("Skip frames identical to the previous one")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if settings.changeDetectionEnabled {
                    Picker("Detection Threshold", selection: $settings.changeDetectionThreshold) {
                        Text("0.1%").tag(0.001)
                        Text("0.5%").tag(0.005)
                        Text("1%").tag(0.01)
                        Text("3%").tag(0.03)
                    }
                    Text("Lower values detect smaller changes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Auto Stop") {
                Picker("Max Frames", selection: $settings.maxFrames) {
                    ForEach(Self.frameOptions, id: \.self) { value in
                        Text(value == 0 ? "∞" : "\(value)").tag(value)
                    }
                }

                Picker("Max Recording Duration", selection: $settings.maxDuration) {
                    ForEach(Self.durationOptions, id: \.self) { value in
                        Text(ElapsedTimeFormatter.durationLabel(value)).tag(value)
                    }
                }

                Text("Recording stops when either limit is reached first")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Interaction") {
                Toggle("Show Cursor", isOn: $settings.showCursor)
                    .disabled(settings.interactionCapture)
                Text("Shows the mouse cursor in captured frames")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Interaction Capture", isOn: $settings.interactionCapture)
                Text("Automatically captures frames on click and drag, and records event metadata")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
