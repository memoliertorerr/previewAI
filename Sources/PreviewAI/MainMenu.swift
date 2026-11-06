import AppKit

/// A menu-bar app never shows its main menu, but AppKit still uses it to turn ⌘C / ⌘A / ⌘W
/// into actions for the key window — so the summary text supports copy and select-all.
@MainActor
func makeMainMenu() -> NSMenu {
    let main = NSMenu()

    let appItem = NSMenuItem()
    let appMenu = NSMenu()
    appMenu.addItem(NSMenuItem(title: "Quit PreviewAI", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    appItem.submenu = appMenu
    main.addItem(appItem)

    let editItem = NSMenuItem()
    let edit = NSMenu(title: "Edit")
    edit.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
    edit.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
    editItem.submenu = edit
    main.addItem(editItem)

    let windowItem = NSMenuItem()
    let window = NSMenu(title: "Window")
    window.addItem(NSMenuItem(title: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
    windowItem.submenu = window
    main.addItem(windowItem)
    return main
}
