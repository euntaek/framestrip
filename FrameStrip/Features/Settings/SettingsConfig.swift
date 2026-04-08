import SwiftUI

enum SettingsConfig {
    // MARK: - Window

    static let windowWidth: CGFloat = 600
    static let windowHeight: CGFloat = 550
    static let sidebarWidth: CGFloat = 180

    // MARK: - Sidebar Icon

    static let iconSize: CGFloat = 26
    static let iconFontSize: CGFloat = 13
    static let iconForeground = Color(white: 0.82)
    static let iconGradientTop = Color(white: 0.40)
    static let iconGradientBottom = Color(white: 0.22)
    static let iconCornerRadius: CGFloat = 6
    static let iconShadowOpacity: Double = 0.2
    static let iconShadowRadius: CGFloat = 0.5

    // MARK: - About

    static let aboutIconSize: CGFloat = 64
    static let githubURL = URL(string: "https://github.com/euntaek/framestrip")
    static let licenseName = "License"
    static let licenseURL = URL(string: "https://github.com/euntaek/framestrip/blob/main/LICENSE")
    static let copyright = "© 2026 Euntaek Kim"

    // MARK: - Prompt

    static let templateEditorHeight: CGFloat = 200
    static let chipCornerRadius: CGFloat = 5
    static let chipBackgroundOpacity: Double = 0.07
    static let copiedFeedbackDuration: TimeInterval = 0.8
    static let chipAnimationDuration: TimeInterval = 0.15
}
