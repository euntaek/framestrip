import CoreGraphics

class ChangeDetector {
    private var previousPixels: [UInt8]?
    private var previousWidth: Int = 0
    private var previousHeight: Int = 0
    private let threshold: Double
    private let maxComparisonSide: Int = 400
    private let colorSpace = CGColorSpaceCreateDeviceRGB()

    init(threshold: Double) {
        self.threshold = threshold
    }

    func hasChanged(_ image: CGImage) -> Bool {
        let (pixels, w, h) = downsampleAndExtract(image)

        defer {
            previousPixels = pixels
            previousWidth = w
            previousHeight = h
        }

        guard let prev = previousPixels,
              previousWidth == w, previousHeight == h else {
            return true
        }

        let pixelCount = w * h
        var sum: Int = 0

        for i in 0..<pixelCount {
            let offset = i * 4
            sum += abs(Int(pixels[offset]) - Int(prev[offset]))
            sum += abs(Int(pixels[offset + 1]) - Int(prev[offset + 1]))
            sum += abs(Int(pixels[offset + 2]) - Int(prev[offset + 2]))
        }

        let changeRate = Double(sum) / Double(pixelCount * 255 * 3)
        return changeRate > threshold
    }

    func reset() {
        previousPixels = nil
        previousWidth = 0
        previousHeight = 0
    }

    private func downsampleAndExtract(_ image: CGImage) -> (pixels: [UInt8], width: Int, height: Int) {
        let longSide = max(image.width, image.height)
        let w: Int, h: Int
        if longSide <= maxComparisonSide {
            w = image.width
            h = image.height
        } else {
            let scale = CGFloat(maxComparisonSide) / CGFloat(longSide)
            w = max(1, Int(CGFloat(image.width) * scale))
            h = max(1, Int(CGFloat(image.height) * scale))
        }

        let bytesPerRow = w * 4
        var pixels = [UInt8](repeating: 0, count: h * bytesPerRow)

        pixels.withUnsafeMutableBufferPointer { buffer in
            guard let ctx = CGContext(
                data: buffer.baseAddress,
                width: w, height: h,
                bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
            ) else { return }
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        }

        return (pixels, w, h)
    }
}
