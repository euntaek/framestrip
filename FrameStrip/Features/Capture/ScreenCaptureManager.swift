import ScreenCaptureKit
import CoreGraphics
import ImageIO
import AppKit

class ScreenCaptureManager {
    enum CaptureError: Error {
        case permissionDenied
        case noDisplayFound
        case captureFailed
    }

    private var cachedFilter: SCContentFilter?
    private var cachedScaleFactor: CGFloat?

    func hasPermission() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    func requestPermission() {
        CGRequestScreenCaptureAccess()
    }

    /// 녹화 세션 시작 시 호출. display/앱 필터를 캐싱하여 매 프레임 쿼리를 제거.
    func prepareForCapture(on screen: NSScreen) async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        guard let display = content.displays.first(where: { $0.displayID == screen.displayID }) else {
            throw CaptureError.noDisplayFound
        }

        let selfApp = content.applications.first { $0.bundleIdentifier == Bundle.main.bundleIdentifier }
        let excludedApps = selfApp.map { [$0] } ?? []

        cachedFilter = SCContentFilter(display: display, excludingApplications: excludedApps, exceptingWindows: [])
        cachedScaleFactor = screen.backingScaleFactor
    }

    func endCapture() {
        cachedFilter = nil
        cachedScaleFactor = nil
    }

    func captureRegion(_ region: CGRect, on screen: NSScreen, showsCursor: Bool = false) async throws -> CGImage {
        do {
            // 캐시가 없으면 fallback으로 직접 쿼리
            let filter: SCContentFilter
            let scaleFactor: CGFloat

            if let cached = cachedFilter, let cachedScale = cachedScaleFactor {
                filter = cached
                scaleFactor = cachedScale
            } else {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard let display = content.displays.first(where: { $0.displayID == screen.displayID }) else {
                    throw CaptureError.noDisplayFound
                }
                let selfApp = content.applications.first { $0.bundleIdentifier == Bundle.main.bundleIdentifier }
                let excludedApps = selfApp.map { [$0] } ?? []
                filter = SCContentFilter(display: display, excludingApplications: excludedApps, exceptingWindows: [])
                scaleFactor = screen.backingScaleFactor
            }

            // 서브픽셀 좌표로 캡처 시 보간이 발생하여 흐려짐
            let pw = max(1, round(region.width * scaleFactor))
            let ph = max(1, round(region.height * scaleFactor))
            let snappedRect = CGRect(
                x: round(region.origin.x * scaleFactor) / scaleFactor,
                y: round(region.origin.y * scaleFactor) / scaleFactor,
                width: pw / scaleFactor,
                height: ph / scaleFactor
            )

            let config = SCStreamConfiguration()
            config.sourceRect = snappedRect
            config.width = Int(pw)
            config.height = Int(ph)
            // .automatic(기본값)은 해상도를 낮출 수 있음
            config.captureResolution = .best
            config.showsCursor = showsCursor
            config.pixelFormat = kCVPixelFormatType_32BGRA

            return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        } catch let error as CaptureError {
            throw error
        } catch {
            let nsError = error as NSError
            if nsError.domain == SCStreamError.errorDomain,
               nsError.code == SCStreamError.Code.userDeclined.rawValue {
                throw CaptureError.permissionDenied
            }
            throw CaptureError.captureFailed
        }
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return deviceDescription[key] as? CGDirectDisplayID ?? 0
    }
}
