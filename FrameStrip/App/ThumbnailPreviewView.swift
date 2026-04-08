import SwiftUI

struct ThumbnailPreviewView: View {
    let image: NSImage
    let frameCount: Int

    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: ThumbnailConfig.maxWidth)
                .clipShape(RoundedRectangle(cornerRadius: ThumbnailConfig.cornerRadius))

            Text("Frame #\(frameCount)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(8)
    }
}
