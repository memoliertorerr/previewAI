import Foundation

/// Small in-memory LRU of finished summaries, so re-opening the same file is instant.
/// Never touches disk.
@MainActor
public final class SummaryCache {
    public struct Key: Hashable, Sendable {
        var path: String
        var modified: Date?
        var size: Int?
        var provider: ProviderID
        var model: String
        var length: SummaryLength

        init(url: URL, provider: ProviderID, model: String, length: SummaryLength) {
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
            path = url.standardizedFileURL.path
            modified = values?.contentModificationDate
            size = values?.fileSize
            self.provider = provider
            self.model = model
            self.length = length
        }
    }

    public let capacity: Int
    private var entries: [Key: String] = [:]
    private var order: [Key] = []  // least recently used first

    public init(capacity: Int = 20) {
        self.capacity = capacity
    }

    public var count: Int { entries.count }

    func value(for key: Key) -> String? {
        guard let value = entries[key] else { return nil }
        touch(key)
        return value
    }

    func store(_ value: String, for key: Key) {
        entries[key] = value
        touch(key)
        while order.count > capacity {
            entries.removeValue(forKey: order.removeFirst())
        }
    }

    public func removeAll() {
        entries.removeAll()
        order.removeAll()
    }

    private func touch(_ key: Key) {
        order.removeAll { $0 == key }
        order.append(key)
    }
}
