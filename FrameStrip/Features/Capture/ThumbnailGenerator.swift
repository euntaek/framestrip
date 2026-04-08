import AppKit
import CoreGraphics

enum ThumbnailGenerator {
    private static let colorSpace = CGColorSpaceCreateDeviceRGB()

    static func generate(from cgImage: CGImage) -> NSImage? {
        let originalWidth = CGFloat(cgImage.width)
        let originalHeight = CGFloat(cgImage.height)
        let maxWidth = ThumbnailConfig.maxWidth

        let targetWidth: CGFloat
        let targetHeight: CGFloat

        if originalWidth <= maxWidth {
            targetWidth = originalWidth
            targetHeight = originalHeight
        } else {
            let scale = maxWidth / originalWidth
            targetWidth = maxWidth
            targetHeight = round(originalHeight * scale)
        }

        let w = max(1, Int(targetWidth))
        let h = max(1, Int(targetHeight))
        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue

        guard let ctx = CGContext(
            data: nil, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w * 4,
            space: colorSpace, bitmapInfo: bitmapInfo
        ) else { return nil }

        ctx.interpolationQuality = .high
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))

        guard let scaledImage = ctx.makeImage() else { return nil }
        return NSImage(cgImage: scaledImage, size: NSSize(width: targetWidth, height: targetHeight))
    }
}
