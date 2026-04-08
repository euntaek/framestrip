import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private let appState = AppState()
    private let menuManager = MenuManager()
    private lazy var settingsWindowController = SettingsWindowController(appState: appState)
    private lazy var coordinator = RecordingCoordinator(appState: appState)
    private var completionPanel: CompletionPanelWindow?
    private var lastCompletionInfo: CompletionInfo?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if appState.status == .selecting || appState.status == .adjusting {
            coordinator.closeAllSelectionWindows()
        }

        if appState.isRecording || coordinator.isFinalizing {
            completionPanel?.dismiss()
            coordinator.requestApplicationTermination()
            return .terminateLater
        }
        return .terminateNow
    }

    func openSettings() {
        settingsWindowController.showWindow()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        wireCallbacks()

        coordinator.registerHotkey()

        NotificationCenter.default.addObserver(forName: .hotkeyDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.coordinator.registerHotkey()
        }

        let captureManager = ScreenCaptureManager()
        if !captureManager.hasPermission() {
            captureManager.requestPermission()
            menuManager.showPermissionDenied()
        }
    }

    // MARK: - Callback Wiring

    private func wireCallbacks() {
        // 메뉴 → 코디네이터
        menuManager.onStartStopClicked = { [weak self] in
            guard let self else { return }
            if self.coordinator.isRecording {
                self.coordinator.stopRecording()
            } else {
                self.coordinator.handleHotkey()
            }
        }
        menuManager.onOpenSettings = { [weak self] in
            self?.settingsWindowController.showWindow()
        }
        menuManager.onCopyPrompt = { [weak self] in
            guard let self, let info = self.lastCompletionInfo else { return }
            let template = SettingsManager.shared.promptTemplate
            let prompt = PromptGenerator.generate(template: template, info: info)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(prompt, forType: .string)
        }

        // 코디네이터 → 메뉴
        coordinator.onRecordingStarted = { [weak self] in
            guard let self else { return }
            self.menuManager.lastSaveFolder = self.appState.lastSaveFolder
            self.menuManager.updateForRecording()
            self.menuManager.updateIcon(for: .recording)
            let elapsed = self.appState.elapsedTime
            let interval = SettingsManager.shared.captureInterval
            self.menuManager.updateStatusText(elapsed: elapsed, interval: interval, changeDetection: SettingsManager.shared.changeDetectionEnabled)
        }

        coordinator.onFinalizingStarted = { [weak self] frameCount in
            guard let self else { return }
            self.menuManager.lastSaveFolder = self.appState.lastSaveFolder
            self.menuManager.updateForFinalizing(frameCount: frameCount)
            self.menuManager.updateIcon(for: .finalizing)
        }

        coordinator.onRecordingStopped = { [weak self] in
            guard let self else { return }
            self.menuManager.lastSaveFolder = self.appState.lastSaveFolder
            self.menuManager.updateForIdle()
            self.menuManager.updateIcon(for: .idle)
            self.menuManager.clearStatusText()
        }

        coordinator.onError = { [weak self] message in
            guard let self else { return }
            self.menuManager.updateIcon(for: .error(message))
            self.menuManager.updateErrorStatus(message)
        }

        coordinator.onErrorCleared = { [weak self] in
            guard let self else { return }
            self.menuManager.updateIcon(for: .idle)
            self.menuManager.updateForIdle()
        }

        coordinator.onPermissionGranted = { [weak self] in
            self?.menuManager.removePermissionDenied()
        }

        coordinator.onPermissionDenied = { [weak self] in
            self?.menuManager.showPermissionDenied()
        }

        coordinator.onStatusUpdate = { [weak self] elapsed, interval, changeDetection in
            self?.menuManager.updateStatusText(elapsed: elapsed, interval: interval, changeDetection: changeDetection)
        }

        coordinator.onThumbnailUpdated = { [weak self] image, frameCount in
            guard let self else { return }
            self.menuManager.updateThumbnail(image: image, frameCount: frameCount)
            if self.coordinator.isFinalizing {
                self.menuManager.updateFinalizingStatus(frameCount: frameCount)
            }
        }

        coordinator.onRecordingCompleted = { [weak self] info in
            guard info.frameCount > 0 else { return }
            self?.lastCompletionInfo = info
            self?.menuManager.enableCopyPrompt(true)
            self?.showCompletionPanel(info)
        }

        coordinator.onTerminationReady = {
            NSApp.reply(toApplicationShouldTerminate: true)
        }
    }

    private func showCompletionPanel(_ info: CompletionInfo) {
        completionPanel?.dismiss()
        let panel = CompletionPanelWindow(info: info)
        panel.onDismissed = { [weak self] in
            self?.completionPanel = nil
        }
        completionPanel = panel
        panel.show()
    }
}
