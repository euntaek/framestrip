import Testing
import Foundation
@testable import FrameStrip

@Suite("PromptGenerator Tests")
struct PromptGeneratorTests {

    private func makeInfo(
        frameCount: Int = 42,
        skippedCount: Int = 7,
        folderPath: String = "/Users/test/framestrip/framestrip_20260331_174529",
        interval: Double = 1.0,
        changeDetection: Bool = true,
        format: String = "PNG",
        duration: TimeInterval = 42
    ) -> CompletionInfo {
        CompletionInfo(
            frameCount: frameCount,
            skippedCount: skippedCount,
            interactionEventCount: 0,
            folder: URL(fileURLWithPath: folderPath),
            lastThumbnail: nil,
            interval: interval,
            changeDetection: changeDetection,
            format: format,
            duration: duration
        )
    }

    @Test("모든 변수 치환")
    func allVariablesSubstituted() {
        let info = makeInfo()
        let template = "@{{path}} — {{frameCount}}f, {{interval}}s, {{format}}, {{changeDetection}}, {{skippedCount}} skipped, {{duration}}"
        let result = PromptGenerator.generate(template: template, info: info)
        #expect(result == "@/Users/test/framestrip/framestrip_20260331_174529 — 42f, 1.0s, PNG, on, 7 skipped, 00:42")
    }

    @Test("빈 템플릿 → 기본 템플릿 fallback")
    func emptyTemplateFallback() {
        let info = makeInfo()
        let result = PromptGenerator.generate(template: "", info: info)
        #expect(result.contains("@\"/Users/test/framestrip/framestrip_20260331_174529\""))
        #expect(result.contains("session.json"))
    }

    @Test("미지원 변수 원본 유지")
    func unknownVariablePreserved() {
        let info = makeInfo()
        let template = "Hello {{unknown}} world"
        let result = PromptGenerator.generate(template: template, info: info)
        #expect(result == "Hello {{unknown}} world")
    }

    @Test("변수 없는 순수 텍스트")
    func plainTextTemplate() {
        let info = makeInfo()
        let template = "Just plain text"
        let result = PromptGenerator.generate(template: template, info: info)
        #expect(result == "Just plain text")
    }

    @Test("특수문자 경로 (공백, 한글)")
    func pathWithSpecialCharacters() {
        let info = makeInfo(folderPath: "/Users/test/frame strip/한글폴더")
        let template = "@{{path}}"
        let result = PromptGenerator.generate(template: template, info: info)
        #expect(result == "@/Users/test/frame strip/한글폴더")
    }

    @Test("changeDetection off 시 값")
    func changeDetectionOff() {
        let info = makeInfo(skippedCount: 0, changeDetection: false)
        let template = "{{changeDetection}} ({{skippedCount}})"
        let result = PromptGenerator.generate(template: template, info: info)
        #expect(result == "off (0)")
    }

    @Test("folder nil 시 path 빈 문자열")
    func nilFolderPath() {
        let info = CompletionInfo(
            frameCount: 10, skippedCount: 0, interactionEventCount: 0, folder: nil, lastThumbnail: nil,
            interval: 1.0, changeDetection: false, format: "PNG", duration: 10
        )
        let template = "@{{path}}"
        let result = PromptGenerator.generate(template: template, info: info)
        #expect(result == "@")
    }

    @Test("defaultTemplate 내용 검증")
    func defaultTemplateContent() {
        #expect(PromptGenerator.defaultTemplate.contains("@\"{{path}}\""))
        #expect(PromptGenerator.defaultTemplate.contains("<ui-motion-reference>"))
        #expect(PromptGenerator.defaultTemplate.contains("<source-material>"))
        #expect(PromptGenerator.defaultTemplate.contains("</source-material>"))
        #expect(PromptGenerator.defaultTemplate.contains("</ui-motion-reference>"))
    }

    @Test("defaultTemplate에 analysis-rules 및 output-boundaries 섹션 포함")
    func defaultTemplateHasSections() {
        #expect(PromptGenerator.defaultTemplate.contains("<analysis-rules>"))
        #expect(PromptGenerator.defaultTemplate.contains("</analysis-rules>"))
        #expect(PromptGenerator.defaultTemplate.contains("<output-boundaries>"))
        #expect(PromptGenerator.defaultTemplate.contains("</output-boundaries>"))
        #expect(PromptGenerator.defaultTemplate.contains("session.json"))
    }

    @Test("metadata 섹션 내 path 변수 치환")
    func metadataPathSubstituted() {
        let info = makeInfo()
        let result = PromptGenerator.generate(template: "", info: info)
        #expect(result.contains("session.json"))
        #expect(!result.contains("{{path}}/session.json"))
    }
}
