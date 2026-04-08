import Foundation
import Testing
@testable import FrameStrip

@Suite("SettingsManager Tests")
struct SettingsManagerTests {

    private func makeSUT() -> SettingsManager {
        let suiteName = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return SettingsManager(defaults: defaults)
    }

    @Test("기본값 확인")
    func defaultValues() {
        let sut = makeSUT()
        #expect(sut.captureInterval == 1.0)
        #expect(sut.imageFormat == .png)
        #expect(sut.jpegQuality == 0.8)
        #expect(sut.maxFrames == 0)
        #expect(sut.maxDuration == 0)
        #expect(sut.saveFolderPath == "~/framestrip")
        #expect(sut.changeDetectionEnabled == false)
        #expect(sut.changeDetectionThreshold == 0.005)
    }

    @Test("값 변경 후 persistence 확인")
    func persistence() {
        let suiteName = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!

        let sut1 = SettingsManager(defaults: defaults)
        sut1.captureInterval = 2.5
        sut1.imageFormat = .jpeg
        sut1.jpegQuality = 0.6
        sut1.changeDetectionEnabled = true
        sut1.changeDetectionThreshold = 0.05

        let sut2 = SettingsManager(defaults: defaults)
        #expect(sut2.captureInterval == 2.5)
        #expect(sut2.imageFormat == .jpeg)
        #expect(sut2.jpegQuality == 0.6)
        #expect(sut2.changeDetectionEnabled == true)
        #expect(sut2.changeDetectionThreshold == 0.05)
    }

    @Test("captureInterval 범위 제한: 0.1 ~ 10.0")
    func captureIntervalClamping() {
        let sut = makeSUT()
        sut.captureInterval = 0.05
        #expect(sut.captureInterval == 0.1)
        sut.captureInterval = 15.0
        #expect(sut.captureInterval == 10.0)
    }

    @Test("jpegQuality 범위 제한: 0.1 ~ 1.0")
    func jpegQualityClamping() {
        let sut = makeSUT()
        sut.jpegQuality = 0.05
        #expect(sut.jpegQuality == 0.1)
        sut.jpegQuality = 1.5
        #expect(sut.jpegQuality == 1.0)
    }

    @Test("saveFolderURL tilde expansion")
    func saveFolderURL() {
        let sut = makeSUT()
        let url = sut.saveFolderURL
        #expect(!url.path.contains("~"))
        #expect(url.path.hasSuffix("/framestrip"))
    }

    @Test("language 기본값 system")
    func languageDefault() {
        let sut = makeSUT()
        #expect(sut.language == .system)
    }

    @Test("language 변경 후 persistence 확인")
    func languagePersistence() {
        let suiteName = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!

        let sut1 = SettingsManager(defaults: defaults)
        sut1.language = .ko

        let sut2 = SettingsManager(defaults: defaults)
        #expect(sut2.language == .ko)
    }

    @Test("language ko → AppleLanguages 설정")
    func languageKoSetsAppleLanguages() {
        let suiteName = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let sut = SettingsManager(defaults: defaults)

        sut.language = .ko

        let appleLanguages = defaults.array(forKey: "AppleLanguages") as? [String]
        #expect(appleLanguages == ["ko"])
    }

    @Test("language en → AppleLanguages 설정")
    func languageEnSetsAppleLanguages() {
        let suiteName = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let sut = SettingsManager(defaults: defaults)

        sut.language = .en

        let appleLanguages = defaults.array(forKey: "AppleLanguages") as? [String]
        #expect(appleLanguages == ["en"])
    }

    @Test("language system → AppleLanguages 제거")
    func languageSystemRemovesAppleLanguages() {
        let suiteName = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let sut = SettingsManager(defaults: defaults)

        sut.language = .ko
        #expect(defaults.array(forKey: "AppleLanguages") as? [String] == ["ko"])

        sut.language = .system
        // AppleLanguages는 시스템 특수 키라 removeObject 후에도 시스템 기본값이 남음
        // suite의 persistent domain에서 키가 제거되었는지 확인
        let domain = defaults.persistentDomain(forName: suiteName)
        #expect(domain?["AppleLanguages"] == nil)
    }

    @Test("promptTemplate 기본값은 빈 문자열")
    func promptTemplateDefault() {
        let sut = makeSUT()
        #expect(sut.promptTemplate == "")
    }

    @Test("promptTemplate 저장/로드")
    func promptTemplatePersistence() {
        let suiteName = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!

        let sut1 = SettingsManager(defaults: defaults)
        sut1.promptTemplate = "Custom template {{path}}"

        let sut2 = SettingsManager(defaults: defaults)
        #expect(sut2.promptTemplate == "Custom template {{path}}")
    }

    @Test("showCursor 기본값 false")
    func showCursorDefault() {
        let sut = makeSUT()
        #expect(sut.showCursor == false)
    }

    @Test("interactionCapture 기본값 false")
    func interactionCaptureDefault() {
        let sut = makeSUT()
        #expect(sut.interactionCapture == false)
    }

    @Test("showCursor persistence")
    func showCursorPersistence() {
        let suiteName = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!

        let sut1 = SettingsManager(defaults: defaults)
        sut1.showCursor = true

        let sut2 = SettingsManager(defaults: defaults)
        #expect(sut2.showCursor == true)
    }

    @Test("interactionCapture persistence")
    func interactionCapturePersistence() {
        let suiteName = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!

        let sut1 = SettingsManager(defaults: defaults)
        sut1.interactionCapture = true

        let sut2 = SettingsManager(defaults: defaults)
        #expect(sut2.interactionCapture == true)
    }

    @Test("interactionCapture ON → showCursor 자동 ON")
    func interactionCaptureAutoEnablesCursor() {
        let sut = makeSUT()
        sut.showCursor = false
        sut.interactionCapture = true
        #expect(sut.showCursor == true)
    }

    @Test("interactionCapture OFF → showCursor 자동 복원 없음 (ON 유지)")
    func interactionCaptureOffKeepsCursorOn() {
        let sut = makeSUT()
        sut.interactionCapture = true
        #expect(sut.showCursor == true)
        sut.interactionCapture = false
        #expect(sut.showCursor == true)
    }
}
