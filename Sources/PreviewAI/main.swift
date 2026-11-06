import AppKit

// A write to a closed pipe must fail with EPIPE, never kill the app (CLI providers also set
// F_SETNOSIGPIPE per pipe; this is the app-wide backstop).
signal(SIGPIPE, SIG_IGN)

// AppKit lifecycle: predictable activation for a menu-bar (LSUIElement) app.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.mainMenu = makeMainMenu()
app.run()
