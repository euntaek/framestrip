import Testing
import Foundation
import CoreGraphics
@testable import FrameStrip

@Suite("ChangeDetector Tests")
struct ChangeDetectorTests {

    private func makeImage(width: Int = 100, height: Int = 100, r: UInt8, g: UInt8, b: UInt8) -> CGImage {
        makeTestImage(width: width, height: height, r: r, g: g, b: b)
    }

    private func makeHalfChangedImage(width: Int = 100, height: Int = 100,
                                       leftR: UInt8, leftG: UInt8, leftB: UInt8,
                                       rightR: UInt8, rightG: UInt8, rightB: UInt8) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        let ctx = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: colorSpace, bitmapInfo: bitmapInfo
        )!
        ctx.setFillColor(red: CGFloat(leftR) / 255, green: CGFloat(leftG) / 255, blue: CGFloat(leftB) / 255, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
        ctx.setFillColor(red: CGFloat(rightR) / 255, green: CGFloat(rightG) / 255, blue: CGFloat(rightB) / 255, alpha: 1)
        ctx.fill(CGRect(x: width / 2, y: 0, width: width / 2, height: height))
        return ctx.makeImage()!
    }

    @Test("첫 프레임은 항상 변화 있음")
    func firstFrameAlwaysChanged() {
        let detector = ChangeDetector(threshold: 0.01)
        let image = makeImage(r: 128, g: 128, b: 128)
        #expect(detector.hasChanged(image) == true)
    }

    @Test("동일 이미지 연속 → 변화 없음")
    func identicalFramesNoChange() {
        let detector = ChangeDetector(threshold: 0.01)
        let image = makeImage(r: 128, g: 128, b: 128)
        _ = detector.hasChanged(image)
        #expect(detector.hasChanged(image) == false)
    }

    @Test("완전히 다른 이미지 → 변화 있음")
    func totallyDifferentFrames() {
        let detector = ChangeDetector(threshold: 0.01)
        let black = makeImage(r: 0, g: 0, b: 0)
        let white = makeImage(r: 255, g: 255, b: 255)
        _ = detector.hasChanged(black)
        #expect(detector.hasChanged(white) == true)
    }

    @Test("임계값 경계: 50% 변화가 1% 임계값 초과")
    func halfChangeExceedsLowThreshold() {
        let detector = ChangeDetector(threshold: 0.01)
        let allBlack = makeImage(r: 0, g: 0, b: 0)
        let halfWhite = makeHalfChangedImage(leftR: 255, leftG: 255, leftB: 255, rightR: 0, rightG: 0, rightB: 0)
        _ = detector.hasChanged(allBlack)
        #expect(detector.hasChanged(halfWhite) == true)
    }

    @Test("reset 후 다음 프레임은 항상 변화 있음")
    func resetMakesNextFrameChanged() {
        let detector = ChangeDetector(threshold: 0.01)
        let image = makeImage(r: 128, g: 128, b: 128)
        _ = detector.hasChanged(image)
        _ = detector.hasChanged(image)
        detector.reset()
        #expect(detector.hasChanged(image) == true)
    }

    @Test("비정사각형 이미지 처리")
    func nonSquareImage() {
        let detector = ChangeDetector(threshold: 0.01)
        let wide = makeImage(width: 400, height: 50, r: 100, g: 100, b: 100)
        let wideDifferent = makeImage(width: 400, height: 50, r: 200, g: 200, b: 200)
        _ = detector.hasChanged(wide)
        #expect(detector.hasChanged(wideDifferent) == true)
    }

    @Test("큰 이미지 다운스케일 동작 (400px 초과)")
    func largeImageDownscaled() {
        let detector = ChangeDetector(threshold: 0.01)
        let large = makeImage(width: 1920, height: 1080, r: 50, g: 50, b: 50)
        let largeDiff = makeImage(width: 1920, height: 1080, r: 200, g: 200, b: 200)
        _ = detector.hasChanged(large)
        #expect(detector.hasChanged(largeDiff) == true)
    }

    @Test("높은 임계값(10%) 설정 시 작은 변화는 무시")
    func highThresholdIgnoresSmallChange() {
        let detector = ChangeDetector(threshold: 0.10)
        let base = makeImage(r: 128, g: 128, b: 128)
        let slightlyDifferent = makeImage(r: 130, g: 130, b: 130)
        _ = detector.hasChanged(base)
        #expect(detector.hasChanged(slightlyDifferent) == false)
    }
}
