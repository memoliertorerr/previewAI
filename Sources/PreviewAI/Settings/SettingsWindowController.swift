import AppKit
import PreviewAICore
import SwiftUI

/// A standard settings window. The app stays an accessory (no Dock icon); it's activated while
/// the window is open so text fields get keyboard focus.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let model: SettingsModel

    init(model: SettingsModel) {
        self.model = model
    }

    func show(tab: SettingsTab? = nil) {
        if let tab { model.tab = tab }
        let window = window ?? makeWindow()
        self.window = window
        model.recordingWindow = window
        model.windowWillShow()
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 440),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: true
        )
        window.title = "PreviewAI Settings"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: SettingsView(model: model))
        window.center()
        window.setFrameAutosaveName("PreviewAISettings")
        window.delegate = self
        return window
    }

    /// Switching away mid-recording must not leave the global hotkey paused.
    func windowDidResignKey(_ notification: Notification) {
        model.endShortcutRecording()
    }

    func windowWillClose(_ notification: Notification) {
        model.endShortcutRecording()
        model.clearProviderFeedback()
        // Hand focus back to whatever the user was using (usually Finder).
        NSApp.deactivate()
    }
}
