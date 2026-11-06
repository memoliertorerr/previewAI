import Foundation

/// Where non-secret settings live. `UserDefaultsStore` in the app, `InMemoryKeyValueStore` in
/// tests (tests never create real defaults suites — they'd write to ~/Library/Preferences).
@MainActor
public protocol KeyValueStore: AnyObject {
    func data(forKey key: String) -> Data?
    func set(_ data: Data?, forKey key: String)
}

@MainActor
public final class UserDefaultsStore: KeyValueStore {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func data(forKey key: String) -> Data? { defaults.data(forKey: key) }

    public func set(_ data: Data?, forKey key: String) {
        if let data { defaults.set(data, forKey: key) } else { defaults.removeObject(forKey: key) }
    }
}

@MainActor
public final class InMemoryKeyValueStore: KeyValueStore {
    public private(set) var values: [String: Data] = [:]

    public init() {}

    public func data(forKey key: String) -> Data? { values[key] }

    public func set(_ data: Data?, forKey key: String) { values[key] = data }
}
