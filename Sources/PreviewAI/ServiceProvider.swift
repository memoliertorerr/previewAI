import AppKit

/// Handles the "Summarize with PreviewAI" Service (Finder → right-click → Quick Actions /
/// Services). macOS passes the files with read access, so this path also works sandboxed,
/// and users can bind it to a shortcut in System Settings → Keyboard → Keyboard Shortcuts.
@MainActor
final class ServiceProvider: NSObject {
    var onFiles: (([URL]) -> Void)?

    /// Selector must match `NSMessage` in Info.plist: summarizeFiles:userData:error:
    @objc func summarizeFiles(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        guard !urls.isEmpty else {
            error.pointee = "No files were passed to PreviewAI." as NSString
            return
        }
        onFiles?(urls)
    }
}
