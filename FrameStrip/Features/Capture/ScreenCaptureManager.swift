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
    }

    func endCapture() {
        cachedFilter = nil
    }

    func captureRegion(_ region: CGRect, on screen: NSScreen, showsCursor: Bool = false) async throws -> CGImage {
        do {
            // 캐시가 없으면 fallback으로 직접 쿼리
            let filter: SCContentFilter

            if let cached = cachedFilter {
                filter = cached
            } else {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard let display = content.displays.first(where: { $0.displayID == screen.displayID }) else {
                    throw CaptureError.noDisplayFound
                }
                let selfApp = content.applications.first { $0.bundleIdentifier == Bundle.main.bundleIdentifier }
                let excludedApps = selfApp.map { [$0] } ?? []
                filter = SCContentFilter(display: display, excludingApplications: excludedApps, exceptingWindows: [])
            }

            // 정수 points로 스냅하여 서브픽셀 보간 방지
            let pw = max(1, round(region.width))
            let ph = max(1, round(region.height))
            let snappedRect = CGRect(
                x: round(region.origin.x),
                y: round(region.origin.y),
                width: pw,
                height: ph
            )

            let config = SCStreamConfiguration()
            config.sourceRect = snappedRect
            config.width = Int(pw)
            config.height = Int(ph)
            // 디스플레이 scaleFactor와 무관하게 1x로 캡처
            config.captureResolution = .nominal
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
