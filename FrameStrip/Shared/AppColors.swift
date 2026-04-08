import AppKit

enum AppColors {
    /// #EF4444 — 녹화 중 테두리, 아이콘
    static let recording = NSColor(red: 239/255, green: 68/255, blue: 68/255, alpha: 1.0)

    /// 영역 선택 오버레이 배경 (35% 검정)
    static let overlayBackground = NSColor(red: 0, green: 0, blue: 0, alpha: 0.35)

    /// 크기 배지 배경 (75% 검정)
    static let badgeBackground = NSColor(red: 0, green: 0, blue: 0, alpha: 0.75)

    static let badgeText = NSColor.white

    // MARK: - Selection Handles & Control Panel

    static let handleFill = NSColor.white
    static let handleShadow = NSColor(red: 0, green: 0, blue: 0, alpha: 0.4)

    static let changeDetectionOnText = NSColor(red: 129/255, green: 199/255, blue: 132/255, alpha: 1)
    static let changeDetectionOffText = NSColor(red: 1, green: 1, blue: 1, alpha: 0.35)

    static let recordButton = NSColor(red: 0, green: 122/255, blue: 1, alpha: 1)
    static let finalizingActionBackground = recording.withAlphaComponent(0.45)

    static let panelSeparator = NSColor(red: 1, green: 1, blue: 1, alpha: 0.1)
}
