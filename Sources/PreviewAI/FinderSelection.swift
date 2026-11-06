#if !APPSTORE
import AppKit

/// Reads the selected items in Finder via Apple Events. Direct-distribution build only — the
/// App Store build uses the Service entry point instead (see docs/ARCHITECTURE.md).
@MainActor
enum FinderSelection {
    enum Result: Equatable {
        case files([URL])
        case notFinder
        case empty
        case permissionDenied
        case failed(String)
    }

    private static let finderBundleID = "com.apple.finder"
    private static let source = """
    tell application "Finder"
        set output to ""
        repeat with anItem in (get selection)
            set output to output & POSIX path of (anItem as alias) & linefeed
        end repeat
        return output
    end tell
    """
    private static var script: NSAppleScript?

    static func current() -> Result {
        guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == finderBundleID else {
            return .notFinder
        }
        if script == nil { script = NSAppleScript(source: source) }
        var error: NSDictionary?
        let output = script?.executeAndReturnError(&error)
        if let error {
            let code = error[NSAppleScript.errorNumber] as? Int
            // errAEEventNotPermitted: the user denied (or hasn't granted) Automation access.
            if code == -1743 { return .permissionDenied }
            return .failed(error[NSAppleScript.errorMessage] as? String ?? "Finder didn't respond.")
        }
        let paths = (output?.stringValue ?? "")
            .split(separator: "\n")
            .map { URL(fileURLWithPath: String($0)) }
        return paths.isEmpty ? .empty : .files(paths)
    }
}
#endif
