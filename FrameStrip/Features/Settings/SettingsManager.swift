import Foundation
import AppKit

@Observable
class SettingsManager {
    enum ImageFormat: String, Hashable, CaseIterable {
        case png, jpeg
    }

    enum Language: String, Hashable, CaseIterable {
        case system, ko, en
    }

    static let shared = SettingsManager()

    private let defaults: UserDefaults

    // Backing storage — @Observable synthesises access/mutation tracking automatically.
    // We avoid didSet self-assignment (which causes infinite recursion under @Observable)
    // by clamping in a dedicated setter method.

    private var _captureInterval: Double = 1.0
    private var _jpegQuality: Double = 0.8

    var captureInterval: Double {
        get { _captureInterval }
        set {
            let clamped = max(0.1, min(10.0, newValue))
            _captureInterval = clamped
            defaults.set(clamped, forKey: Keys.captureInterval)
        }
    }

    var imageFormat: ImageFormat {
        didSet { defaults.set(imageFormat.rawValue, forKey: Keys.imageFormat) }
    }

    var jpegQuality: Double {
        get { _jpegQuality }
        set {
            let clamped = max(0.1, min(1.0, newValue))
            _jpegQuality = clamped
            defaults.set(clamped, forKey: Keys.jpegQuality)
        }
    }

    var maxFrames: Int {
        didSet { defaults.set(maxFrames, forKey: Keys.maxFrames) }
    }

    var maxDuration: Int {
        didSet { defaults.set(maxDuration, forKey: Keys.maxDuration) }
    }

    var changeDetectionEnabled: Bool {
        didSet { defaults.set(changeDetectionEnabled, forKey: Keys.changeDetectionEnabled) }
    }

    var changeDetectionThreshold: Double {
        didSet { defaults.set(changeDetectionThreshold, forKey: Keys.changeDetectionThreshold) }
    }

    var saveFolderPath: String {
        didSet { defaults.set(saveFolderPath, forKey: Keys.saveFolderPath) }
    }

    var hotkeyKeyCode: UInt32 {
        didSet { defaults.set(Int(hotkeyKeyCode), forKey: Keys.hotkeyKeyCode) }
    }

    var hotkeyModifiers: UInt32 {
        didSet { defaults.set(Int(hotkeyModifiers), forKey: Keys.hotkeyModifiers) }
    }

    var showCursor: Bool {
        didSet { defaults.set(showCursor, forKey: Keys.showCursor) }
    }

    var interactionCapture: Bool {
        didSet {
            defaults.set(interactionCapture, forKey: Keys.interactionCapture)
            if interactionCapture {
                showCursor = true
            }
        }
    }

    var language: Language {
        didSet {
            defaults.set(language.rawValue, forKey: Keys.language)
            switch language {
            case .ko, .en:
                defaults.set([language.rawValue], forKey: "AppleLanguages")
            case .system:
                defaults.removeObject(forKey: "AppleLanguages")
            }
        }
    }

    var promptTemplate: String {
        didSet { defaults.set(promptTemplate, forKey: Keys.promptTemplate) }
    }

    var saveFolderURL: URL {
        URL(fileURLWithPath: NSString(string: saveFolderPath).expandingTildeInPath)
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        defaults.register(defaults: [
            Keys.captureInterval: 1.0,
            Keys.imageFormat: ImageFormat.png.rawValue,
            Keys.jpegQuality: 0.8,
            Keys.maxFrames: 0,
            Keys.maxDuration: 0,
            Keys.saveFolderPath: "~/framestrip",
            Keys.changeDetectionEnabled: false,
            Keys.changeDetectionThreshold: 0.005,
            Keys.hotkeyKeyCode: 23,       // '5' key
            Keys.hotkeyModifiers: NSEvent.ModifierFlags.option.rawValue | NSEvent.ModifierFlags.shift.rawValue,  // ⌥⇧
            Keys.showCursor: false,
            Keys.interactionCapture: false,
            Keys.language: Language.system.rawValue,
            Keys.promptTemplate: "",
        ])

        _captureInterval = defaults.double(forKey: Keys.captureInterval)
        imageFormat = ImageFormat(rawValue: defaults.string(forKey: Keys.imageFormat) ?? "png") ?? .png
        _jpegQuality = defaults.double(forKey: Keys.jpegQuality)
        maxFrames = defaults.integer(forKey: Keys.maxFrames)
        maxDuration = defaults.integer(forKey: Keys.maxDuration)
        changeDetectionEnabled = defaults.bool(forKey: Keys.changeDetectionEnabled)
        let rawThreshold = defaults.double(forKey: Keys.changeDetectionThreshold)
        changeDetectionThreshold = rawThreshold == 0 ? 0.005 : rawThreshold
        saveFolderPath = defaults.string(forKey: Keys.saveFolderPath) ?? "~/framestrip"
        hotkeyKeyCode = UInt32(defaults.integer(forKey: Keys.hotkeyKeyCode))
        hotkeyModifiers = UInt32(defaults.integer(forKey: Keys.hotkeyModifiers))
        showCursor = defaults.bool(forKey: Keys.showCursor)
        interactionCapture = defaults.bool(forKey: Keys.interactionCapture)
        language = Language(rawValue: defaults.string(forKey: Keys.language) ?? "system") ?? .system
        promptTemplate = defaults.string(forKey: Keys.promptTemplate) ?? ""

        // 잘못된 기본값(0x0A00) 마이그레이션
        if hotkeyModifiers == 0x0A00 {
            hotkeyModifiers = UInt32(NSEvent.ModifierFlags.option.rawValue | NSEvent.ModifierFlags.shift.rawValue)
        }
    }

    private enum Keys {
        static let captureInterval = "captureInterval"
        static let imageFormat = "imageFormat"
        static let jpegQuality = "jpegQuality"
        static let maxFrames = "maxFrames"
        static let maxDuration = "maxDuration"
        static let saveFolderPath = "saveFolderPath"
        static let hotkeyKeyCode = "hotkeyKeyCode"
        static let hotkeyModifiers = "hotkeyModifiers"
        static let changeDetectionEnabled = "changeDetectionEnabled"
        static let changeDetectionThreshold = "changeDetectionThreshold"
        static let showCursor = "showCursor"
        static let interactionCapture = "interactionCapture"
        static let language = "language"
        static let promptTemplate = "promptTemplate"
    }
}
