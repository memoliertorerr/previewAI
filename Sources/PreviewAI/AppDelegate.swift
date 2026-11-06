import AppKit
import PreviewAICore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = makeStatusItem()
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
        let summarize = NSMenuItem(title: "Summarize Selection", action: nil, keyEquivalent: "")
        summarize.isEnabled = false
        menu.addItem(summarize)
        menu.addItem(.separator())
        let settings = NSMenuItem(title: "Settings…", action: nil, keyEquivalent: ",")
        settings.isEnabled = false
        menu.addItem(settings)
        menu.addItem(NSMenuItem(title: "Quit PreviewAI", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        menu.autoenablesItems = false
        return menu
    }
}
