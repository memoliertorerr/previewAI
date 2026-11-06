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
    // Returns a list (not a joined string, so newlines in names are safe). Items that can't
    // be coerced to a file alias are skipped instead of failing the whole selection.
    private static let source = """
    tell application "Finder"
        set thePaths to {}
        repeat with anItem in (get selection)
            try
                set end of thePaths to POSIX path of (anItem as alias)
            end try
        end repeat
        return thePaths
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
            switch code {
            // errAEEventNotPermitted: the user denied (or hasn't granted) Automation access.
            case -1743: return .permissionDenied
            // errAETimeout: usually the first-run permission prompt was left unanswered.
            case -1712: return .failed("Finder didn't answer in time. If macOS asked for permission, allow it and try again.")
            default: return .failed("Couldn't read Finder's selection. Try selecting the file again.")
            }
        }
        guard let output else { return .empty }
        var paths: [URL] = []
        if output.numberOfItems > 0 {
            for index in 1...output.numberOfItems {  // Apple Event lists are 1-based
                if let path = output.atIndex(index)?.stringValue { paths.append(URL(fileURLWithPath: path)) }
            }
        }
        return paths.isEmpty ? .empty : .files(paths)
    }
}
#endif
