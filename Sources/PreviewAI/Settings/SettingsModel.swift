import AppKit
import Observation
import PreviewAICore

enum SettingsTab: Hashable {
    case general, providers, about
}

/// Settings-window state and actions that need app services (hotkey, workspace).
@MainActor
@Observable
final class SettingsModel {
    var settings: SettingsStore
    let registry: ProviderRegistry
    let recorder: ShortcutRecorderModel
    var tab: SettingsTab = .general
    var shortcutWarning: String?
    var testResult: ConnectionTestResult?
    var isTesting = false
    var availableModels: [String] = []
    var modelListError: String?
    var loginItemError: String?
    @ObservationIgnored let launchAtLogin: LaunchAtLogin

    /// Re-registers the global hotkey; returns false if macOS refused it.
    @ObservationIgnored var applyShortcut: ((KeyCombo) -> Bool)?
    /// Pauses the global hotkey while recording, so pressing the current combo is recordable.
    @ObservationIgnored var setHotkeyPaused: ((Bool) -> Void)?
    @ObservationIgnored private var keyMonitor: Any?

    init(settings: SettingsStore, registry: ProviderRegistry) {
        self.settings = settings
        self.registry = registry
        self.recorder = ShortcutRecorderModel(combo: settings.shortcut)
        self.launchAtLogin = LaunchAtLogin(settings: settings, service: SystemLoginItemService())
        launchAtLogin.syncFromSystem()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        loginItemError = launchAtLogin.set(enabled)
    }

    // MARK: Shortcut

    func beginShortcutRecording() {
        guard !recorder.isRecording else { return }
        recorder.start()
        setHotkeyPaused?(true)
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let outcome = self.recorder.handle(keyCode: event.keyCode, modifierFlags: event.modifierFlags.rawValue)
            switch outcome {
            case .ignored:
                return event
            case .recorded, .cleared:
                self.commitShortcut(self.recorder.combo)
            case .cancelled:
                self.endShortcutRecording()
            case .rejected:
                break
            }
            return nil  // swallow keys while recording
        }
    }

    func endShortcutRecording() {
        if recorder.isRecording { recorder.cancel() }
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        setHotkeyPaused?(false)
    }

    private func commitShortcut(_ combo: KeyCombo) {
        settings.shortcut = combo
        endShortcutRecording()
        refreshShortcutWarning()
    }

    func refreshShortcutWarning() {
        let combo = settings.shortcut
        if HotkeyManager.isReservedBySystem(combo) {
            shortcutWarning = "\(combo.displayString) is also a macOS shortcut, so it may not reach PreviewAI. Choose another, or turn that one off in System Settings → Keyboard → Keyboard Shortcuts."
        } else if applyShortcut?(combo) == false {
            shortcutWarning = "\(combo.displayString) is already used by another app. Choose another shortcut."
        } else {
            shortcutWarning = nil
        }
    }

    // MARK: Providers

    func testConnection() {
        isTesting = true
        testResult = nil
        let provider = registry.current
        Task {
            let result = await ConnectionTester.run(provider)
            self.testResult = result
            self.isTesting = false
        }
    }

    func refreshModels() {
        modelListError = nil
        let provider = OpenAICompatibleProvider(config: settings.openAICompatible,
                                                apiKey: settings.apiKey(for: .openAICompatible))
        Task {
            do {
                self.availableModels = try await provider.listModels()
                if self.availableModels.isEmpty { self.modelListError = "The server returned no models." }
            } catch {
                self.availableModels = []
                self.modelListError = error.localizedDescription
            }
        }
    }

    func clearProviderFeedback() {
        testResult = nil
        availableModels = []
        modelListError = nil
    }

    func openAppleIntelligenceSettings() {
        let pane = URL(string: "x-apple.systempreferences:com.apple.Siri-Settings.extension")!
        if !NSWorkspace.shared.open(pane) {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
        }
    }
}
