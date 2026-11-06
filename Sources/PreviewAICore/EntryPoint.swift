import Foundation

/// Shared filtering for every way a file reaches the app (hotkey, Service, Open With, picker).
public enum EntryPoint {
    /// Keeps file URLs that exist and are regular files — or document packages we can read
    /// (e.g. `.rtfd`). Folders and missing files are dropped.
    public static func resolveFiles(_ urls: [URL]) -> [URL] {
        urls.filter { url in
            guard url.isFileURL else { return false }
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return false }
            return !isDirectory.boolValue || DocumentLoader.kind(for: url) != nil
        }
    }

    /// Converts pasteboard objects to path URLs. Finder often passes file-reference URLs
    /// (`file:///.file/id=…`); they are resolved while still `NSURL`s, because Swift's `URL`
    /// can't represent an unresolved reference.
    public static func fileURLs(fromPasteboardObjects objects: [Any]) -> [URL] {
        objects.compactMap { object in
            guard let url = object as? NSURL else { return nil }
            return url.isFileReferenceURL() ? url.filePathURL : url as URL
        }
    }
}
