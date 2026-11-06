import AppKit
import PreviewAICore
import UniformTypeIdentifiers

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let hotkey = HotkeyManager()
    private let services = ServiceProvider()
    private let session = SummarySession()
    private let settings = SettingsStore(store: UserDefaultsStore(), secrets: KeychainSecretStore())
    private lazy var registry = ProviderRegistry(settings: settings)
    private lazy var panelModel = PanelModel(session: session)
    private lazy var panel = SummaryPanelController(model: panelModel)
    /// Menu line for problems that shouldn't pop up the panel (e.g. the shortcut is taken).
    private let statusLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = makeStatusItem()

        hotkey.onPress = { [weak self] in self?.hotkeyPressed() }
        panelModel.length = settings.length
        panelModel.onLengthChange = { [weak self] length in self?.settings.length = length }

        let combo = settings.shortcut
        if HotkeyManager.isReservedBySystem(combo) {
            showInMenu("\(combo.displayString) is also a macOS shortcut — change one of them")
        }
        if !hotkey.register(combo) {
            showInMenu("Shortcut \(combo.displayString) is taken by another app")
        }

        panelModel.onOpenSettings = { [weak self] in self?.openProviderSettings() }

        services.onFiles = { [weak self] urls in self?.handle(files: urls) }
        NSApp.servicesProvider = services
        NSUpdateDynamicServices()
    }

    func applicationWillTerminate(_ notification: Notification) {
        session.close()
        #if !APPSTORE
        CLIRunner.terminateAll()  // don't leave a claude/codex child running after quit
        #endif
    }

    /// Open With… and dropping files onto the app icon.
    func application(_ application: NSApplication, open urls: [URL]) {
        handle(files: urls)
    }

    // MARK: - Entry points

    private func hotkeyPressed() {
        // Like Space in Quick Look: the shortcut closes the panel — unless the Finder
        // selection changed, in which case it summarizes the new file.
        guard panel.isVisible else {
            summarizeFinderSelection()
            return
        }
        #if !APPSTORE
        if case .files(let urls) = FinderSelection.current(),
           let first = EntryPoint.resolveFiles(urls).first,
           first.standardizedFileURL != panelModel.content.fileURL?.standardizedFileURL {
            handle(files: urls)
            return
        }
        #endif
        panel.close()
    }

    private func summarizeFinderSelection() {
        #if APPSTORE
        showInPanel("Right-click a document in Finder → Services → Summarize with PreviewAI.")
        #else
        switch FinderSelection.current() {
        case .files(let urls): handle(files: urls)
        case .notFinder, .empty: showInPanel("Select a document in Finder, then press \(settings.shortcut.displayString).")
        case .permissionDenied: showInPanel("PreviewAI needs permission to see Finder's selection. Allow it in System Settings → Privacy & Security → Automation → PreviewAI → Finder.")
        case .failed(let message): showInPanel(message)
        }
        #endif
    }

    @objc private func summarizeSelection() {
        summarizeFinderSelection()
    }

    @objc private func summarizeFile() {
        NSApp.activate()
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = Self.supportedTypes
        panel.message = "Choose a document to summarize"
        let response = panel.runModal()
        // Give focus back to the previous app (usually Finder) so the shortcut keeps working.
        NSApp.deactivate()
        guard response == .OK else { return }
        handle(files: panel.urls)
    }

    /// Every entry point lands here.
    private func handle(files urls: [URL]) {
        let files = EntryPoint.resolveFiles(urls)
        guard let first = files.first else {
            showInPanel("That selection isn't a document PreviewAI can read.")
            return
        }
        panelModel.additionalFiles = files.count - 1
        panel.show()
        session.summarize(url: first, provider: registry.current, length: panelModel.length)
    }

    private func showInPanel(_ message: String) {
        panelModel.additionalFiles = 0
        session.showMessage(message)
        panel.show()
    }

    /// Until the PreviewAI settings window exists (PA11), "Open Settings" goes to the
    /// relevant System Settings pane.
    private func openProviderSettings() {
        panel.close()
        let pane = URL(string: "x-apple.systempreferences:com.apple.Siri-Settings.extension")!
        if !NSWorkspace.shared.open(pane) {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
        }
    }

    // MARK: - Menu

    private func showInMenu(_ status: String) {
        statusLine.title = status
        statusLine.isHidden = false
    }

    private func makeStatusItem() -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let image = NSImage(systemSymbolName: "text.page.badge.magnifyingglass", accessibilityDescription: "PreviewAI")
            ?? NSImage(systemSymbolName: "doc.text.magnifyingglass", accessibilityDescription: "PreviewAI")
        image?.isTemplate = true
        item.button?.image = image
        item.menu = makeMenu()
        return item
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let combo = settings.shortcut
        let summarize = NSMenuItem(title: "Summarize Selection", action: #selector(summarizeSelection), keyEquivalent: "")
        summarize.target = self
        summarize.toolTip = "Shortcut: \(combo.displayString)"
        menu.addItem(summarize)

        let shortcutHint = NSMenuItem(title: "Shortcut: \(combo.displayString)", action: nil, keyEquivalent: "")
        shortcutHint.isEnabled = false
        menu.addItem(shortcutHint)

        let file = NSMenuItem(title: "Summarize File…", action: #selector(summarizeFile), keyEquivalent: "o")
        file.target = self
        menu.addItem(file)

        statusLine.isEnabled = false
        statusLine.isHidden = true
        menu.addItem(statusLine)

        menu.addItem(.separator())
        let settings = NSMenuItem(title: "Settings…", action: nil, keyEquivalent: ",")
        settings.isEnabled = false
        menu.addItem(settings)
        menu.addItem(NSMenuItem(title: "Quit PreviewAI", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    static let supportedTypes: [UTType] = [
        .pdf, .plainText, .rtf, .rtfd, .html,
        UTType("net.daringfireball.markdown"),
        UTType("org.openxmlformats.wordprocessingml.document"),
    ].compactMap { $0 }
}
