# Changelog

## [1.1.0] — 2026-04-13

### Added
- Built-in auto-update via Sparkle — check for updates from the menu bar or General settings
- "Automatically check for updates" toggle in Settings > General
- "Check for Updates..." menu item below Settings
- `make appcast` command to generate Sparkle update feed (appcast.xml)

### Changed
- Activation policy (Dock visibility) now managed centrally — settings window and update dialogs share policy without conflicts
- Update relaunch is postponed if a recording is in progress

## [1.0.1] — 2026-04-09

### Fixed
- Capture resolution now consistent across displays — same visual region produces identical pixel dimensions regardless of monitor scale factor
- First few capture frames no longer hit slow fallback path when starting a recording

## [1.0.0] — 2026-04-07

First public release.

### Added
- Region selection with resize handles and multi-monitor support
- Timed capture intervals (0.1s–10s)
- Auto-stop by frame count or duration
- Change detection — skip identical frames automatically
- Interaction capture — auto-capture on mouse click/drag with event metadata in `session.json`
- Cursor display option
- AI prompt generation with customizable template and variable chips
- Live thumbnail preview in menu bar during recording
- PNG / JPEG output with adjustable quality
- Korean / English localization with system language detection
- Global keyboard shortcut (default: Option+Shift+5, customizable)
- Settings UI with sidebar layout (Capture / General / Prompt / About)
