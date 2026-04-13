import AppKit
import SwiftUI

class MenuManager: NSObject {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var startStopItem: NSMenuItem!
    private var statusTextItem: NSMenuItem?
    private var openFolderItem: NSMenuItem!
    private var settingsItem: NSMenuItem!
    private var copyPromptItem: NSMenuItem!
    private var checkForUpdatesItem: NSMenuItem?
    private var canCheckForUpdatesObservation: Any?
    private var canCheckForUpdatesGetter: (() -> Bool)?

    private var iconPulseTimer: Timer?
    private var permissionDeniedItem: NSMenuItem?
    private var openSystemSettingsItem: NSMenuItem?
    private var thumbnailItem: NSMenuItem?
    private var thumbnailHostingView: NSHostingView<ThumbnailPreviewView>?
    private var pendingThumbnail: (image: NSImage, frameCount: Int)?

    var onStartStopClicked: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onCopyPrompt: (() -> Void)?
    var onCheckForUpdates: (() -> Void)?
    var lastSaveFolder: URL?

    override init() {
        super.init()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            let icon = NSImage(named: "MenuBarIcon")
            icon?.isTemplate = true
            icon?.size = NSSize(width: 19.5, height: 18)
            button.image = icon
        }

        buildMenu()
        statusItem.menu = menu
        menu.delegate = self
    }

    // MARK: - Menu Construction

    private func buildMenu() {
        menu = NSMenu()
        menu.autoenablesItems = false

        startStopItem = NSMenuItem(title: String(localized: "Select Region & Start Recording"), action: #selector(handleStartStop), keyEquivalent: "")
        startStopItem.target = self
        startStopItem.image = NSImage(systemSymbolName: "scope", accessibilityDescription: String(localized: "Select region"))
        menu.addItem(startStopItem)

        menu.addItem(NSMenuItem.separator())

        copyPromptItem = NSMenuItem(title: String(localized: "Copy Recent Prompt"), action: #selector(handleCopyPrompt), keyEquivalent: "")
        copyPromptItem.target = self
        copyPromptItem.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: String(localized: "Copy Recent Prompt"))
        copyPromptItem.isEnabled = false
        menu.addItem(copyPromptItem)

        openFolderItem = NSMenuItem(title: String(localized: "Open Recent Save Folder"), action: #selector(openLastFolder), keyEquivalent: "")
        openFolderItem.target = self
        openFolderItem.image = NSImage(systemSymbolName: "folder", accessibilityDescription: String(localized: "Recent folder"))
        openFolderItem.isEnabled = false
        menu.addItem(openFolderItem)

        let openBaseFolderItem = NSMenuItem(title: String(localized: "Open Save Folder"), action: #selector(openBaseFolder), keyEquivalent: "")
        openBaseFolderItem.target = self
        openBaseFolderItem.image = NSImage(systemSymbolName: "folder.badge.gearshape", accessibilityDescription: String(localized: "Save folder"))
        menu.addItem(openBaseFolderItem)

        menu.addItem(NSMenuItem.separator())

        settingsItem = NSMenuItem(title: String(localized: "Settings..."), action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        settingsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: String(localized: "Settings"))
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: String(localized: "Quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.image = NSImage(systemSymbolName: "power", accessibilityDescription: String(localized: "Quit"))
        menu.addItem(quitItem)
    }

    func addCheckForUpdatesItem() {
        let updateItem = NSMenuItem(title: String(localized: "Check for Updates..."), action: #selector(handleCheckForUpdates), keyEquivalent: "")
        updateItem.target = self
        updateItem.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: String(localized: "Check for Updates"))
        checkForUpdatesItem = updateItem

        let index = menu.index(of: settingsItem)
        if index != -1 {
            menu.insertItem(updateItem, at: index + 1)
        }
    }

    // MARK: - Menu State Transitions

    func updateForRecording() {
        startStopItem.isEnabled = true
        startStopItem.title = String(localized: "Stop Recording")
        startStopItem.action = #selector(handleStartStop)
        startStopItem.image = NSImage(systemSymbolName: "stop.fill", accessibilityDescription: String(localized: "Stop Recording"))

        if let image = startStopItem.image {
            startStopItem.image = image.withSymbolConfiguration(
                NSImage.SymbolConfiguration(paletteColors: [.systemRed])
            )
        }

        ensureStatusTextItem()

        settingsItem.isEnabled = false
        checkForUpdatesItem?.isEnabled = false
        if lastSaveFolder != nil {
            openFolderItem.isEnabled = true
        }
    }

    func updateForFinalizing(frameCount: Int) {
        startStopItem.title = String(localized: "Saving...")
        startStopItem.action = #selector(handleStartStop)
        startStopItem.image = NSImage(systemSymbolName: "hourglass", accessibilityDescription: String(localized: "Saving"))
        startStopItem.isEnabled = false

        ensureStatusTextItem()
        updateFinalizingStatus(frameCount: frameCount)

        settingsItem.isEnabled = false
        checkForUpdatesItem?.isEnabled = false
        openFolderItem.isEnabled = lastSaveFolder != nil
    }

    func updateForIdle() {
        startStopItem.title = String(localized: "Select Region & Start Recording")
        startStopItem.action = #selector(handleStartStop)
        startStopItem.image = NSImage(systemSymbolName: "scope", accessibilityDescription: String(localized: "Select region"))
        startStopItem.isEnabled = true

        removeStatusTextItem()

        removeThumbnail()

        settingsItem.isEnabled = true
        syncCheckForUpdatesState()
        openFolderItem.isEnabled = lastSaveFolder != nil
    }

    func showPermissionDenied() {
        guard permissionDeniedItem == nil else { return }

        let deniedItem = NSMenuItem(title: String(localized: "Screen recording permission is required"), action: nil, keyEquivalent: "")
        deniedItem.isEnabled = false
        deniedItem.image = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: String(localized: "Permission required"))
        self.permissionDeniedItem = deniedItem

        let openSettingsItem = NSMenuItem(title: String(localized: "Open System Settings"), action: #selector(openSystemSettings), keyEquivalent: "")
        openSettingsItem.target = self
        openSettingsItem.image = NSImage(systemSymbolName: "arrow.right.circle", accessibilityDescription: String(localized: "System Settings"))
        self.openSystemSettingsItem = openSettingsItem

        menu.insertItem(deniedItem, at: 0)
        menu.insertItem(openSettingsItem, at: 1)
        menu.insertItem(NSMenuItem.separator(), at: 2)

        startStopItem.isHidden = true
    }

    func removePermissionDenied() {
        if let item = permissionDeniedItem {
            menu.removeItem(item)
            permissionDeniedItem = nil
        }
        if let item = openSystemSettingsItem {
            menu.removeItem(item)
            openSystemSettingsItem = nil
        }
        // 권한 denied 블록 아래 추가된 separator 제거
        if let firstItem = menu.items.first, firstItem.isSeparatorItem {
            menu.removeItem(firstItem)
        }
        startStopItem.isHidden = false
        startStopItem.isEnabled = true
    }

    func enableCopyPrompt(_ enabled: Bool) {
        copyPromptItem.isEnabled = enabled
    }

    // MARK: - Thumbnail Preview

    func updateThumbnail(image: NSImage, frameCount: Int) {
        pendingThumbnail = (image, frameCount)

        guard thumbnailHostingView != nil else { return }
        applyPendingThumbnail()
    }

    private func applyPendingThumbnail() {
        guard let (image, frameCount) = pendingThumbnail else { return }
        let rootView = ThumbnailPreviewView(image: image, frameCount: frameCount)

        if let hostingView = thumbnailHostingView {
            hostingView.rootView = rootView
            hostingView.frame.size = hostingView.fittingSize
        } else {
            let hostingView = NSHostingView(rootView: rootView)
            hostingView.frame.size = hostingView.fittingSize

            let item = NSMenuItem()
            item.view = hostingView
            self.thumbnailItem = item
            self.thumbnailHostingView = hostingView

            if let statusTextItem {
                let index = menu.index(of: statusTextItem)
                if index != -1 {
                    menu.insertItem(item, at: index + 1)
                }
            }
        }
    }

    private func removeThumbnail() {
        pendingThumbnail = nil
        if let item = thumbnailItem {
            menu.removeItem(item)
            thumbnailItem = nil
            thumbnailHostingView = nil
        }
    }

    // MARK: - Status Text

    func updateFinalizingStatus(frameCount: Int) {
        let suffix = frameCount > 0 ? " " + String(localized: "\(frameCount) frames") : ""
        statusTextItem?.title = String(localized: "Saving...") + suffix
        statusItem.button?.title = " " + String(localized: "Saving...")
    }

    func updateStatusText(elapsed: TimeInterval, interval: Double, changeDetection: Bool = false) {
        let formatted = ElapsedTimeFormatter.statusText(elapsed: elapsed, interval: interval, changeDetection: changeDetection)
        statusTextItem?.title = formatted
        statusItem.button?.title = " \(formatted)"
    }

    func clearStatusText() {
        statusItem.button?.title = ""
    }

    func updateErrorStatus(_ message: String) {
        ensureStatusTextItem()
        statusTextItem?.title = message
        statusTextItem?.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: String(localized: "Error"))?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: [.systemYellow]))
        if let item = statusTextItem {
            menu.removeItem(item)
            menu.insertItem(item, at: 0)
        }
    }

    // MARK: - Menubar Icon

    func updateIcon(for status: AppState.Status) {
        guard let button = statusItem.button else { return }
        iconPulseTimer?.invalidate()
        iconPulseTimer = nil

        switch status {
        case .idle, .selecting, .adjusting:
            button.image = NSImage(named: "MenuBarIcon")
        case .recording:
            var isVisible = true
            let pulseTimer = Timer(timeInterval: 0.75, repeats: true) { [weak button] _ in
                isVisible.toggle()
                let config = NSImage.SymbolConfiguration(paletteColors: isVisible ? [.systemRed] : [.systemRed.withAlphaComponent(0.3)])
                button?.image = NSImage(systemSymbolName: "record.circle", accessibilityDescription: String(localized: "Recording"))?.withSymbolConfiguration(config)
            }
            RunLoop.current.add(pulseTimer, forMode: .common)
            iconPulseTimer = pulseTimer
            let config = NSImage.SymbolConfiguration(paletteColors: [.systemRed])
            button.image = NSImage(systemSymbolName: "record.circle", accessibilityDescription: String(localized: "Recording"))?.withSymbolConfiguration(config)
        case .finalizing:
            button.image = NSImage(systemSymbolName: "hourglass", accessibilityDescription: String(localized: "Saving"))
        case .error:
            let config = NSImage.SymbolConfiguration(paletteColors: [.systemYellow])
            button.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: String(localized: "Error"))?.withSymbolConfiguration(config)
        }
    }

    private func ensureStatusTextItem() {
        if statusTextItem == nil {
            let statusMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
            statusMenuItem.isEnabled = false
            statusTextItem = statusMenuItem

            let index = menu.index(of: startStopItem)
            if index != -1 {
                menu.insertItem(statusMenuItem, at: index + 1)
            }
        }
    }

    private func removeStatusTextItem() {
        if let statusTextItem {
            menu.removeItem(statusTextItem)
            self.statusTextItem = nil
        }
    }

    // MARK: - Sparkle Integration

    func bindUpdaterState(canCheckForUpdates: @escaping () -> Bool, observe: @escaping (@escaping (Bool) -> Void) -> Any) {
        canCheckForUpdatesGetter = canCheckForUpdates
        checkForUpdatesItem?.isEnabled = canCheckForUpdates()
        canCheckForUpdatesObservation = observe { [weak self] canCheck in
            self?.checkForUpdatesItem?.isEnabled = canCheck
        }
    }

    private func syncCheckForUpdatesState() {
        checkForUpdatesItem?.isEnabled = canCheckForUpdatesGetter?() ?? true
    }

    // MARK: - Actions

    @objc private func handleStartStop() {
        onStartStopClicked?()
    }

    @objc private func handleCopyPrompt() {
        onCopyPrompt?()
    }

    @objc private func openSettings() {
        onOpenSettings?()
    }

    @objc private func openLastFolder() {
        guard let folder = lastSaveFolder else { return }
        NSWorkspace.shared.open(folder)
    }

    @objc private func openBaseFolder() {
        let baseDir = SettingsManager.shared.saveFolderURL
        try? FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)
        NSWorkspace.shared.open(baseDir)
    }

    @objc private func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func handleCheckForUpdates() {
        onCheckForUpdates?()
    }
}

// MARK: - NSMenuDelegate

extension MenuManager: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        applyPendingThumbnail()
    }
}
