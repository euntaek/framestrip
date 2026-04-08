import Foundation

enum ElapsedTimeFormatter {
    static func statusText(elapsed: TimeInterval, interval: Double, changeDetection: Bool = false) -> String {
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        let unit = String(localized: "s", comment: "Second unit abbreviation for recording status")
        let base = String(format: "⏺ %02d:%02d / %.1f", minutes, seconds, interval) + unit
        return changeDetection ? "\(base) △" : base
    }

    static func filenameSuffix(elapsed: TimeInterval) -> String {
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        let millis = Int((elapsed.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%02dm%02ds%03dms", minutes, seconds, millis)
    }

    static func formatTime(_ elapsed: TimeInterval) -> String {
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    static func durationLabel(_ totalSeconds: Int) -> String {
        if totalSeconds == 0 { return "∞" }
        let s = String(localized: "s", comment: "Second unit abbreviation")
        let m = String(localized: "min", comment: "Minute unit abbreviation")
        if totalSeconds < 60 { return "\(totalSeconds)" + s }
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return seconds == 0
            ? "\(minutes)" + m
            : "\(minutes)" + m + " \(seconds)" + s
    }
}
