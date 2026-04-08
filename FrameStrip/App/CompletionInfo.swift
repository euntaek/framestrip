import AppKit

struct CompletionInfo {
    let frameCount: Int
    let skippedCount: Int
    let interactionEventCount: Int
    let folder: URL?
    let lastThumbnail: NSImage?
    let interval: Double
    let changeDetection: Bool
    let format: String
    let duration: TimeInterval

    func withThumbnail(_ image: NSImage?) -> CompletionInfo {
        CompletionInfo(
            frameCount: frameCount,
            skippedCount: skippedCount,
            interactionEventCount: interactionEventCount,
            folder: folder,
            lastThumbnail: image,
            interval: interval,
            changeDetection: changeDetection,
            format: format,
            duration: duration
        )
    }
}
