import Foundation
import AppKit

enum CoordinateUtils {

    /// CG rect (screen-relative, top-left origin) → AppKit window frame (global, bottom-left origin)
    static func cgToAppKitWindowFrame(_ cgRect: CGRect, screenFrame: CGRect) -> CGRect {
        CGRect(
            x: cgRect.origin.x + screenFrame.origin.x,
            y: screenFrame.origin.y + screenFrame.height - cgRect.maxY,
            width: cgRect.width,
            height: cgRect.height
        )
    }

    /// Convenience: NSScreen version
    static func cgToAppKitWindowFrame(_ cgRect: CGRect, on screen: NSScreen) -> CGRect {
        cgToAppKitWindowFrame(cgRect, screenFrame: screen.frame)
    }

    /// AppKit rect (screen-relative, bottom-left origin) → CG rect (screen-relative, top-left origin)
    static func appKitToCG(_ appKitRect: CGRect, screenHeight: CGFloat) -> CGRect {
        CGRect(
            x: appKitRect.origin.x,
            y: screenHeight - appKitRect.maxY,
            width: appKitRect.width,
            height: appKitRect.height
        )
    }

    /// 글로벌 AppKit rect의 중심점이 위치한 스크린 frame 반환.
    /// 어떤 스크린에도 속하지 않으면 가장 가까운 스크린 반환.
    static func screenForCenterPoint(_ globalRect: CGRect, screenFrames: [CGRect]) -> CGRect? {
        let center = CGPoint(x: globalRect.midX, y: globalRect.midY)

        for frame in screenFrames {
            if frame.contains(center) {
                return frame
            }
        }

        var nearest: CGRect?
        var minDist: CGFloat = .infinity
        for frame in screenFrames {
            let nx = max(frame.minX, min(center.x, frame.maxX))
            let ny = max(frame.minY, min(center.y, frame.maxY))
            let dist = (center.x - nx) * (center.x - nx) + (center.y - ny) * (center.y - ny)
            if dist < minDist {
                minDist = dist
                nearest = frame
            }
        }
        return nearest
    }

    /// 글로벌 AppKit rect → 특정 스크린 기준 CG rect (screen-relative, top-left origin)
    static func globalAppKitToCG(_ globalRect: CGRect, screenFrame: CGRect) -> CGRect {
        let localAppKit = CGRect(
            x: globalRect.origin.x - screenFrame.origin.x,
            y: globalRect.origin.y - screenFrame.origin.y,
            width: globalRect.width,
            height: globalRect.height
        )
        return appKitToCG(localAppKit, screenHeight: screenFrame.height)
    }

    /// CG rect를 스크린 범위 내로 클램프 (screen-relative 좌표)
    static func clampToScreenCG(_ region: CGRect, screenWidth: CGFloat, screenHeight: CGFloat) -> CGRect {
        var r = region
        r.size.width = min(r.width, screenWidth)
        r.size.height = min(r.height, screenHeight)
        r.origin.x = max(0, min(r.origin.x, screenWidth - r.width))
        r.origin.y = max(0, min(r.origin.y, screenHeight - r.height))
        return r
    }
}
