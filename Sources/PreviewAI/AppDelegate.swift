import AppKit
import PreviewAICore
import UniformTypeIdentifiers

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let hotkey = HotkeyManager()
    private let services = ServiceProvider()
    /// Temporary feedback line in the menu until the panel exists (PA6 replaces it).
    private let statusLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = makeStatusItem()

        hotkey.onPress = { [weak self] in self?.hotkeyPressed() }
        if !hotkey.register(.default) {
            show(status: "Shortcut \(KeyCombo.default.displayString) is taken by another app")
        }

        services.onFiles = { [weak self] urls in self?.handle(files: urls) }
        NSApp.servicesProvider = services
        NSUpdateDynamicServices()
    }

    /// Open With… and dropping files onto the app icon.
    func application(_ application: NSApplication, open urls: [URL]) {
        handle(files: urls)
    }

    // MARK: - Entry points

    private func hotkeyPressed() {
        #if APPSTORE
        show(status: "Right-click a file → Quick Actions → Summarize with PreviewAI")
        #else
        switch FinderSelection.current() {
        case .files(let urls): handle(files: urls)
        case .notFinder, .empty: show(status: "Select a document in Finder first")
        case .permissionDenied: show(status: "Allow PreviewAI to control Finder in System Settings → Privacy & Security → Automation")
        case .failed(let message): show(status: message)
        }
        #endif
    }

    @objc private func summarizeSelection() {
        hotkeyPressed()
    }

    @objc private func summarizeFile() {
        NSApp.activate()
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = Self.supportedTypes
        panel.message = "Choose a document to summarize"
        guard panel.runModal() == .OK else { return }
        handle(files: panel.urls)
    }

    /// Every entry point lands here.
    private func handle(files urls: [URL]) {
        let files = EntryPoint.resolveFiles(urls)
        guard let first = files.first else {
            show(status: "No readable document was selected")
            return
        }
        let more = files.count > 1 ? " (+\(files.count - 1) more)" : ""
        show(status: "Last file: \(first.lastPathComponent)\(more)")
    }

    // MARK: - Menu

    private func show(status: String) {
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

        let combo = KeyCombo.default
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
