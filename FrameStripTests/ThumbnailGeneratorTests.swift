import Testing
import Foundation
import CoreGraphics
import AppKit
@testable import FrameStrip

@Suite("ThumbnailGenerator Tests")
struct ThumbnailGeneratorTests {

    @Test("넓은 이미지 축소: maxWidth 기준으로 비율 유지")
    func scalesWideImage() {
        let image = makeTestImage(width: 1920, height: 1080)
        let thumbnail = ThumbnailGenerator.generate(from: image)
        #expect(thumbnail != nil)
        #expect(thumbnail!.size.width == ThumbnailConfig.maxWidth)
        let expectedHeight = ThumbnailConfig.maxWidth * (1080.0 / 1920.0)
        #expect(abs(thumbnail!.size.height - expectedHeight) < 1)
    }

    @Test("작은 이미지: maxWidth 이하면 그대로 유지")
    func smallImageUnchanged() {
        let image = makeTestImage(width: 80, height: 60)
        let thumbnail = ThumbnailGenerator.generate(from: image)
        #expect(thumbnail != nil)
        #expect(thumbnail!.size.width == 80)
        #expect(thumbnail!.size.height == 60)
    }

    @Test("세로 이미지: 너비 기준 축소")
    func tallImageScaled() {
        let image = makeTestImage(width: 600, height: 1200)
        let thumbnail = ThumbnailGenerator.generate(from: image)
        #expect(thumbnail != nil)
        #expect(thumbnail!.size.width == ThumbnailConfig.maxWidth)
        let expectedHeight = ThumbnailConfig.maxWidth * (1200.0 / 600.0)
        #expect(abs(thumbnail!.size.height - expectedHeight) < 1)
    }

    @Test("정사각형 이미지 축소")
    func squareImageScaled() {
        let image = makeTestImage(width: 500, height: 500)
        let thumbnail = ThumbnailGenerator.generate(from: image)
        #expect(thumbnail != nil)
        #expect(thumbnail!.size.width == ThumbnailConfig.maxWidth)
        #expect(thumbnail!.size.height == ThumbnailConfig.maxWidth)
    }

    @Test("정확히 maxWidth인 이미지: 축소 안 함")
    func exactMaxWidthNotScaled() {
        let image = makeTestImage(width: Int(ThumbnailConfig.maxWidth), height: 80)
        let thumbnail = ThumbnailGenerator.generate(from: image)
        #expect(thumbnail != nil)
        #expect(thumbnail!.size.width == ThumbnailConfig.maxWidth)
    }
}
