import Testing
import Foundation
import CoreGraphics
@testable import FrameStrip

@Suite("CoordinateUtils Tests")
struct CoordinateUtilsTests {

    @Test("CG→AppKit 변환: 기본 좌표 (주 디스플레이)")
    func cgToAppKitBasic() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let cgRect = CGRect(x: 100, y: 200, width: 300, height: 400)
        let result = CoordinateUtils.cgToAppKitWindowFrame(cgRect, screenFrame: screenFrame)
        #expect(result.origin.x == 100)
        #expect(result.origin.y == 480)
        #expect(result.width == 300)
        #expect(result.height == 400)
    }

    @Test("CG→AppKit 변환: 보조 디스플레이 (음수 origin)")
    func cgToAppKitSecondaryDisplay() {
        let screenFrame = CGRect(x: -1920, y: 0, width: 1920, height: 1080)
        let cgRect = CGRect(x: 100, y: 100, width: 200, height: 200)
        let result = CoordinateUtils.cgToAppKitWindowFrame(cgRect, screenFrame: screenFrame)
        #expect(result.origin.x == -1820)
        #expect(result.origin.y == 780)
        #expect(result.width == 200)
        #expect(result.height == 200)
    }

    @Test("AppKit→CG 변환: 기본 좌표")
    func appKitToCGBasic() {
        let screenHeight: CGFloat = 1080
        let appKitRect = CGRect(x: 100, y: 480, width: 300, height: 400)
        let result = CoordinateUtils.appKitToCG(appKitRect, screenHeight: screenHeight)
        #expect(result.origin.x == 100)
        #expect(result.origin.y == 200)
        #expect(result.width == 300)
        #expect(result.height == 400)
    }

    @Test("왕복 변환: AppKit→CG→AppKit = 원래 값")
    func roundTripAppKitToCGAndBack() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let original = CGRect(x: 100, y: 480, width: 300, height: 400)
        let cg = CoordinateUtils.appKitToCG(original, screenHeight: screenFrame.height)
        let backToAppKit = CoordinateUtils.cgToAppKitWindowFrame(cg, screenFrame: screenFrame)
        #expect(abs(backToAppKit.origin.x - original.origin.x) < 0.001)
        #expect(abs(backToAppKit.origin.y - original.origin.y) < 0.001)
        #expect(abs(backToAppKit.width - original.width) < 0.001)
        #expect(abs(backToAppKit.height - original.height) < 0.001)
    }

    // MARK: - screenForCenterPoint

    @Test("screenForCenterPoint: 주 모니터 내 중심점")
    func screenForCenterPointPrimary() {
        let screens = [
            CGRect(x: 0, y: 0, width: 1920, height: 1080),
            CGRect(x: 1920, y: 0, width: 1920, height: 1080),
        ]
        let rect = CGRect(x: 100, y: 100, width: 300, height: 200)
        let result = CoordinateUtils.screenForCenterPoint(rect, screenFrames: screens)
        #expect(result == screens[0])
    }

    @Test("screenForCenterPoint: 보조 모니터 내 중심점")
    func screenForCenterPointSecondary() {
        let screens = [
            CGRect(x: 0, y: 0, width: 1920, height: 1080),
            CGRect(x: 1920, y: 0, width: 1920, height: 1080),
        ]
        let rect = CGRect(x: 2000, y: 400, width: 300, height: 200)
        let result = CoordinateUtils.screenForCenterPoint(rect, screenFrames: screens)
        #expect(result == screens[1])
    }

    @Test("screenForCenterPoint: 모니터 간 갭 — nearest 선택")
    func screenForCenterPointGap() {
        let screens = [
            CGRect(x: 0, y: 0, width: 1920, height: 1080),
            CGRect(x: 1930, y: 0, width: 1920, height: 1080),
        ]
        let rect = CGRect(x: 1873, y: 450, width: 100, height: 100)
        let result = CoordinateUtils.screenForCenterPoint(rect, screenFrames: screens)
        #expect(result == screens[0])
    }

    // MARK: - globalAppKitToCG

    @Test("globalAppKitToCG: 주 모니터 기준 변환")
    func globalAppKitToCGPrimary() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let globalRect = CGRect(x: 100, y: 480, width: 300, height: 400)
        let result = CoordinateUtils.globalAppKitToCG(globalRect, screenFrame: screenFrame)
        #expect(result.origin.x == 100)
        #expect(result.origin.y == 200)
        #expect(result.width == 300)
        #expect(result.height == 400)
    }

    @Test("globalAppKitToCG: 보조 모니터 기준 변환 (음수 origin)")
    func globalAppKitToCGSecondary() {
        let screenFrame = CGRect(x: -1920, y: 0, width: 1920, height: 1080)
        let globalRect = CGRect(x: -1820, y: 780, width: 200, height: 200)
        let result = CoordinateUtils.globalAppKitToCG(globalRect, screenFrame: screenFrame)
        #expect(result.origin.x == 100)
        #expect(result.origin.y == 100)
        #expect(result.width == 200)
        #expect(result.height == 200)
    }

    // MARK: - clampToScreenCG

    @Test("clampToScreenCG: 완전 내부 — 변경 없음")
    func clampInsideScreen() {
        let region = CGRect(x: 100, y: 100, width: 300, height: 200)
        let result = CoordinateUtils.clampToScreenCG(region, screenWidth: 1920, screenHeight: 1080)
        #expect(result == region)
    }

    @Test("clampToScreenCG: 부분 삐져나감 — 위치 클램프")
    func clampPartialOverflow() {
        let region = CGRect(x: 1800, y: 100, width: 300, height: 200)
        let result = CoordinateUtils.clampToScreenCG(region, screenWidth: 1920, screenHeight: 1080)
        #expect(result.origin.x == 1620)
        #expect(result.origin.y == 100)
        #expect(result.width == 300)
        #expect(result.height == 200)
    }

    @Test("clampToScreenCG: 모니터보다 큰 영역 — 크기+위치 클램프")
    func clampLargerThanScreen() {
        let region = CGRect(x: 100, y: 100, width: 2000, height: 1200)
        let result = CoordinateUtils.clampToScreenCG(region, screenWidth: 1920, screenHeight: 1080)
        #expect(result.origin.x == 0)
        #expect(result.origin.y == 0)
        #expect(result.width == 1920)
        #expect(result.height == 1080)
    }
}
