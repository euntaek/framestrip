import Foundation
import os

enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.ttings.FrameStrip"

    static let recording = Logger(subsystem: subsystem, category: "recording")
    static let capture = Logger(subsystem: subsystem, category: "capture")
}
