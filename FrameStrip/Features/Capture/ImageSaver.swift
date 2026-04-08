import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

class ImageSaver {
    enum SaveError: Error {
        case encodingFailed
        case directoryCreationFailed
    }

    private let baseDirectory: URL

    init(baseDirectory: URL) {
        self.baseDirectory = baseDirectory
    }

    func createSessionFolder() throws -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let folderName = "framestrip_\(formatter.string(from: Date()))"
        let sessionDir = baseDirectory.appendingPathComponent(folderName)
        try FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)
        return sessionDir
    }

    @discardableResult
    func save(image: CGImage, format: SettingsManager.ImageFormat, quality: Double, to sessionDir: URL, frameNumber: Int, elapsedTime: TimeInterval = 0) throws -> URL {
        let ext = format == .png ? "png" : "jpeg"
        let timeSuffix = ElapsedTimeFormatter.filenameSuffix(elapsed: elapsedTime)
        let fileName = String(format: "frame_%03d_%@.%@", frameNumber, timeSuffix, ext)
        let fileURL = sessionDir.appendingPathComponent(fileName)

        let uti = format == .png ? UTType.png.identifier : UTType.jpeg.identifier

        guard let dest = CGImageDestinationCreateWithURL(fileURL as CFURL, uti as CFString, 1, nil) else {
            throw SaveError.encodingFailed
        }

        var options: [CFString: Any] = [:]
        if format == .jpeg {
            options[kCGImageDestinationLossyCompressionQuality] = quality
        }

        CGImageDestinationAddImage(dest, image, options as CFDictionary)

        guard CGImageDestinationFinalize(dest) else {
            throw SaveError.encodingFailed
        }

        return fileURL
    }
}
