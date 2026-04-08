import Testing
import Foundation
import CoreGraphics
@testable import FrameStrip

@Suite("ImageSaver Tests")
struct ImageSaverTests {

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makeTestImage(width: Int = 100, height: Int = 100) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }

    @Test("세션 폴더 생성 형식: framestrip_YYYYMMDD_HHmmss")
    func sessionFolderNaming() throws {
        let baseDir = try makeTempDir()
        let saver = ImageSaver(baseDirectory: baseDir)
        let sessionDir = try saver.createSessionFolder()
        let folderName = sessionDir.lastPathComponent
        #expect(folderName.hasPrefix("framestrip_"))
        #expect(folderName.count == "framestrip_YYYYMMDD_HHmmss".count)
    }

    @Test("PNG 저장: 파일명에 타임스탬프 포함")
    func savePNG() throws {
        let baseDir = try makeTempDir()
        let saver = ImageSaver(baseDirectory: baseDir)
        let sessionDir = try saver.createSessionFolder()
        let image = makeTestImage()

        let url = try saver.save(image: image, format: .png, quality: 1.0, to: sessionDir, frameNumber: 1, elapsedTime: 1.5)

        #expect(url.lastPathComponent == "frame_001_00m01s500ms.png")
        #expect(FileManager.default.fileExists(atPath: url.path))
        let data = try Data(contentsOf: url)
        #expect(data.count > 0)
    }

    @Test("JPEG 저장: 파일명에 타임스탬프 포함")
    func saveJPEG() throws {
        let baseDir = try makeTempDir()
        let saver = ImageSaver(baseDirectory: baseDir)
        let sessionDir = try saver.createSessionFolder()
        let image = makeTestImage()

        let url = try saver.save(image: image, format: .jpeg, quality: 0.8, to: sessionDir, frameNumber: 42, elapsedTime: 125.0)

        #expect(url.lastPathComponent == "frame_042_02m05s000ms.jpeg")
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test("순차 프레임 번호와 타임스탬프")
    func sequentialFrameNumbers() throws {
        let baseDir = try makeTempDir()
        let saver = ImageSaver(baseDirectory: baseDir)
        let sessionDir = try saver.createSessionFolder()
        let image = makeTestImage()

        let url1 = try saver.save(image: image, format: .png, quality: 1.0, to: sessionDir, frameNumber: 1, elapsedTime: 0)
        let url2 = try saver.save(image: image, format: .png, quality: 1.0, to: sessionDir, frameNumber: 2, elapsedTime: 1.0)
        let url3 = try saver.save(image: image, format: .png, quality: 1.0, to: sessionDir, frameNumber: 3, elapsedTime: 2.0)

        #expect(url1.lastPathComponent == "frame_001_00m00s000ms.png")
        #expect(url2.lastPathComponent == "frame_002_00m01s000ms.png")
        #expect(url3.lastPathComponent == "frame_003_00m02s000ms.png")
    }
}
