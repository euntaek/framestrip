PROJECT = FrameStrip.xcodeproj
SCHEME = FrameStrip
DERIVED_DATA = DerivedData
APP = $(DERIVED_DATA)/Build/Products/Release/FrameStrip.app
DMG = FrameStrip.dmg
KEYCHAIN_PROFILE = FrameStrip

# ── Development ──────────────────────────────────────

.PHONY: build test clean

build:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug build

test:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination 'platform=macOS' -only-testing:FrameStripTests test

clean:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Release -derivedDataPath $(DERIVED_DATA) clean
	rm -f $(DMG)

# ── Release ──────────────────────────────────────────
#
# Full release flow:
#   1. make release-build   — clean build with Developer ID signing
#   2. make verify-version  — check version in built app
#   3. make dmg             — package .app into .dmg
#   4. make notarize        — submit .dmg to Apple for notarization
#   5. make staple          — attach notarization ticket to .dmg
#   6. make appcast         — generate appcast.xml for Sparkle updates
#
# Or run all at once:
#   make release
#

.PHONY: release-build verify-version dmg notarize staple appcast release

release-build:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Release -derivedDataPath $(DERIVED_DATA) clean build

verify-version:
	@/usr/bin/defaults read "$(CURDIR)/$(APP)/Contents/Info.plist" CFBundleShortVersionString

dmg:
	$(eval DMG_STAGING := $(shell mktemp -d))
	cp -R "$(APP)" "$(DMG_STAGING)/"
	ln -s /Applications "$(DMG_STAGING)/Applications"
	hdiutil create -volname "FrameStrip" -srcfolder "$(DMG_STAGING)" -ov -format UDZO $(DMG)
	rm -rf "$(DMG_STAGING)"

notarize:
	xcrun notarytool submit $(DMG) --keychain-profile $(KEYCHAIN_PROFILE) --wait

staple:
	xcrun stapler staple $(DMG)

appcast:
	$(eval SPARKLE_BIN := $(shell find ~/Library/Developer/Xcode/DerivedData -name "generate_appcast" -path "*/Sparkle/*" 2>/dev/null | head -1))
	@if [ -z "$(SPARKLE_BIN)" ]; then \
		echo "Error: generate_appcast not found. Build the project first to download Sparkle."; \
		exit 1; \
	fi
	@mkdir -p .appcast-staging
	@cp $(DMG) .appcast-staging/
	$(SPARKLE_BIN) .appcast-staging
	@cp .appcast-staging/appcast.xml appcast.xml
	@echo "Generated appcast.xml"

release: release-build dmg notarize staple appcast
	@echo "Release complete. Distribute $(DMG)"
