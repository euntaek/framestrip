import Testing
import Foundation
@testable import FrameStrip

@Suite("ElapsedTimeFormatter Tests")
struct ElapsedTimeFormatterTests {

    private let secondUnit = String(localized: "s", comment: "Second unit abbreviation for recording status")

    @Test("statusText: 0초")
    func statusTextZero() {
        let result = ElapsedTimeFormatter.statusText(elapsed: 0, interval: 1.0)
        #expect(result == "⏺ 00:00 / 1.0" + secondUnit)
    }

    @Test("statusText: 1분 30초, 0.5초 간격")
    func statusTextNormal() {
        let result = ElapsedTimeFormatter.statusText(elapsed: 90, interval: 0.5)
        #expect(result == "⏺ 01:30 / 0.5" + secondUnit)
    }

    @Test("statusText: 59분 59초")
    func statusTextMax() {
        let result = ElapsedTimeFormatter.statusText(elapsed: 3599, interval: 10.0)
        #expect(result == "⏺ 59:59 / 10.0" + secondUnit)
    }

    @Test("filenameSuffix: 0초")
    func filenameSuffixZero() {
        let result = ElapsedTimeFormatter.filenameSuffix(elapsed: 0)
        #expect(result == "00m00s000ms")
    }

    @Test("filenameSuffix: 1분 1.5초")
    func filenameSuffixNormal() {
        let result = ElapsedTimeFormatter.filenameSuffix(elapsed: 61.5)
        #expect(result == "01m01s500ms")
    }

    @Test("filenameSuffix: 소수점 정밀도")
    func filenameSuffixPrecision() {
        let result = ElapsedTimeFormatter.filenameSuffix(elapsed: 125.0)
        #expect(result == "02m05s000ms")
    }

    @Test("statusText: 변화 감지 ON")
    func statusTextChangeDetection() {
        let result = ElapsedTimeFormatter.statusText(elapsed: 90, interval: 1.0, changeDetection: true)
        #expect(result == "⏺ 01:30 / 1.0" + secondUnit + " △")
    }

    @Test("statusText: 변화 감지 OFF (기본값)")
    func statusTextNoChangeDetection() {
        let result = ElapsedTimeFormatter.statusText(elapsed: 90, interval: 1.0)
        #expect(result == "⏺ 01:30 / 1.0" + secondUnit)
    }
}
