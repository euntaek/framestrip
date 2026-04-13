# FrameStrip

macOS menubar app for capturing UI motion/animation as frame sequences for AI consumption.

## Commands

| Command | Description |
|---------|-------------|
| `make build` | Debug build |
| `make test` | Unit tests |
| `make clean` | Release build artifacts + dmg 제거 |
| `make release` | Full release (build → dmg → notarize → staple) |
| `make release-build` | Release build only (Developer ID signing) |
| `make verify-version` | Built app version 확인 |
| `make dmg` | .dmg 패키징 |
| `make notarize` | Apple 공증 제출 |
| `make staple` | 공증 티켓 스테이플 |

- Testing framework: Swift Testing (`@Suite`, `@Test`, `#expect`). Not XCTest.
- Tests can also run from Xcode GUI (⌘U).
- CLI `xcodebuild test` may fail due to TEST_HOST issues after identity separation.

## Architecture

```
FrameStrip/
├── App/               # AppDelegate, AppState(@Observable), menu bar, coordinator,
│                      # completion panel, CompletionInfo, ThumbnailPreviewView
├── Features/
│   ├── Recording/     # Session management, region selection overlay, RegionFloatingPanel,
│   │                  # control panel (SelectionControlPanel), recording border
│   ├── Capture/       # ScreenCaptureKit wrapper, image saving, change detection, thumbnails,
│   │                  # interaction event model, mouse event monitor, session manifest (JSON)
│   └── Settings/      # NavigationSplitView settings UI (Capture/General/Prompt/About),
│                      # SettingsConfig constants, FlowLayout (inline), window controller
└── Shared/            # Cross-cutting: AppColors, AppLogger, CoordinateUtils,
                       # ElapsedTimeFormatter, GlobalHotkeyManager, KeyCodes,
                       # PromptGenerator, ThumbnailConfig
```

## Tech Stack

- Swift + SwiftUI, macOS 14+ (Sonoma)
- ScreenCaptureKit (`SCScreenshotManager.captureImage`)
- AppDelegate + NSStatusItem (menu bar)
- NSWindow + NSHostingController (settings), NSPanel (floating panels)
- UserDefaults, os.Logger, Carbon EventHotKey
- String Catalog (.xcstrings) + `String(localized:)` (Korean/English)

## Code Organization

- Feature-based: `App/`, `Features/{feature}/`, `Shared/`
- Feature internals are flat. Introduce `Views/`, `Services/` subfolders at 5+ files.
- Naming: `*View`, `*Window`, `*Controller` (UI), `*Manager`, `*Session`, `*Generator` (logic), `*Config`, `*Colors` (constants)
- Xcode `fileSystemSynchronizedGroups` — filesystem moves automatically reflect in project.

## Code Patterns

- **Timer**: Always `RunLoop.add(timer, forMode: .common)`. `.scheduledTimer()` freezes during menu dropdown.
- **Coordinates**: AppKit (bottom-left origin) ↔ CoreGraphics (top-left origin).
- **No magic numbers**: Extract repeated or non-obvious values to `Shared/` constants or Feature-local `*Config` files (e.g. `SettingsConfig`). Inline SwiftUI layout values (padding, font size, corner radius) are acceptable when used once and self-documenting in context.
- **Comments**: WHY only. No WHAT comments.
- **Logging**: `AppLogger.recording` / `AppLogger.capture` (os.Logger), not `print()`.
- **CGColorSpace**: Cache with `static let` for repeated use.
- **NSPanel floating windows**: `.nonactivatingPanel` + `.canJoinAllSpaces` + `.stationary`. `hasShadow = false` (use SwiftUI shadow).
- **NSPanel multi-monitor**: Single NSPanel spanning two monitors breaks NSView rendering. Render per-monitor overlay independently.
- **NSPanel transparent corners**: `.borderless` + `becomesKeyOnlyIfNeeded` + AppKit `NSVisualEffectView` + `layer.cornerRadius`. SwiftUI `VisualEffectBackground` + `clipShape` leaks NSHostingView background at corners.
- **Settings UI**: NavigationSplitView sidebar + detail. Picker(`.menu`) dropdowns, not Steppers. Settings window toggles `NSApp.setActivationPolicy` (`.regular` on open, `.accessory` on close) for Dock visibility.
- **i18n**: `String(localized:)` for AppKit, SwiftUI `Text("key")` auto-localizes. Keys are English source text. Korean translations in `Localizable.xcstrings`. **New strings must be added to xcstrings with Korean translation in the same commit.** Covers Section headers, captions, tooltips. Log messages and filenames stay English.
- **Tooltip**: Control panel chips use `ChipTooltipWindow` (separate NSWindow singleton) instead of native `.help()`. Apply via `.chipTooltip()` ViewModifier.
- **Time/unit formatting**: Use `ElapsedTimeFormatter.durationLabel()`.
- **Permissions**: Check `CGPreflightScreenCaptureAccess()`, request `CGRequestScreenCaptureAccess()`. If broken, check app identity before changing code.

## Threading

- **Main thread**: UI updates, AppState mutations
- **Task (async/await)**: ScreenCaptureKit capture calls
- **saveQueue** (serial DispatchQueue, `.userInitiated`): Image saving, thumbnail generation. Wrap in `autoreleasepool`.
- **Main thread delivery**: `DispatchQueue.main.async` for AppState/callback updates
- **Save queue limit**: Max 10 pending saves. When Interaction Capture is ON, timer frames are limited to 8 (2 slots reserved for event frames). Excess frames are dropped.

## Development Notes

- Code signing uses xcconfig-based separation:
  - `Config/Release.xcconfig` — signing style, hardened runtime, timestamp (git tracked)
  - `Config/Debug.xcconfig` — automatic signing (git tracked)
  - `Config/Signing.local.xcconfig` — Developer Team ID (gitignored)
  - Contributors: copy `Config/Signing.local.example.xcconfig` → `Config/Signing.local.xcconfig` and set Team ID
- Notarization credentials stored in Keychain (profile name: `FrameStrip`). Set up via:
  `xcrun notarytool store-credentials "FrameStrip" --apple-id "EMAIL" --team-id "TEAM_ID" --password "APP_SPECIFIC_PASSWORD"`
- Debug and Release app identities are separate:
  - Debug: `FrameStrip Dev` / `com.ttings.FrameStrip.dev`
  - Release: `FrameStrip` / `com.ttings.FrameStrip`
- If screen recording permission or relaunch behavior looks broken, check app identity first.

## Release

### Versioning

Semantic Versioning: `MAJOR.MINOR.PATCH`
- Patch (1.0.0 → 1.0.1): bug fixes
- Minor (1.0.0 → 1.1.0): new features
- Major (1.0.0 → 2.0.0): breaking changes

Xcode project has `MARKETING_VERSION` (user-facing, e.g. `1.1.0`) and `CURRENT_PROJECT_VERSION` (build number, increment every release).

### Release Process

1. Update `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in Xcode project
2. Update `CHANGELOG.md` with new version entry
3. Build, sign, notarize, and package:
   ```bash
   make release   # release-build → dmg → notarize → staple
   make verify-version
   ```
   Or step by step: `make release-build` → `make dmg` → `make notarize` → `make staple`
4. Commit version bump + changelog
5. Tag and push: `git tag v1.1.0 && git push origin v1.1.0`
6. Create GitHub Release: `gh release create v1.1.0 --title "v1.1.0" --notes-file <(sed -n '/## \[1.1.0\]/,/## \[/p' CHANGELOG.md | sed '$d') FrameStrip.dmg`
   Asset name is always `FrameStrip.dmg` (no version suffix). Landing page download URL depends on this.

### Changelog Format

```markdown
## [X.Y.Z] — YYYY-MM-DD

### Added
- New feature description

### Changed
- Changed behavior description

### Fixed
- Bug fix description
```
