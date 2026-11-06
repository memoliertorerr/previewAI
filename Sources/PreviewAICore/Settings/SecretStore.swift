import Foundation
import Security

/// API keys. Only ever stored here — never in settings, logs, or files.
public protocol SecretStore: AnyObject, Sendable {
    /// nil when no key is stored; throws when the Keychain refuses access.
    func secret(for account: String) throws -> String?
    func setSecret(_ value: String?, for account: String) throws
}

public struct SecretStoreError: LocalizedError, Equatable {
    public let status: OSStatus
    public var errorDescription: String? {
        switch status {
        case errSecAuthFailed, errSecInteractionNotAllowed, errSecUserCanceled:
            "PreviewAI wasn't allowed to use its Keychain item. Enter your API key again in Settings."
        default:
            "The Keychain returned an error (\(status))."
        }
    }
}

/// Generic-password items in the login Keychain. Never used by tests.
public final class KeychainSecretStore: SecretStore, @unchecked Sendable {
    private let service: String

    public init(service: String = PreviewAIInfo.bundleIdentifier) {
        self.service = service
    }

    private func query(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    public func secret(for account: String) throws -> String? {
        var query = query(account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess: return (result as? Data).flatMap { String(data: $0, encoding: .utf8) }
        case errSecItemNotFound: return nil
        default: throw SecretStoreError(status: status)
        }
    }

    public func setSecret(_ value: String?, for account: String) throws {
        let base = query(account)
        guard let value, !value.isEmpty else {
            let status = SecItemDelete(base as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else { throw SecretStoreError(status: status) }
            return
        }
        let data = Data(value.utf8)
        let update = [kSecValueData as String: data]
        var status = SecItemUpdate(base as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var add = base
            add[kSecValueData as String] = data
            add[kSecAttrLabel as String] = "PreviewAI API key (\(account))"
            status = SecItemAdd(add as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw SecretStoreError(status: status) }
    }
}

public final class InMemorySecretStore: SecretStore, @unchecked Sendable {
    private let lock = NSLock()
    private var secrets: [String: String] = [:]
    private var _reads = 0
    /// Accounts whose reads fail as if the Keychain denied access (for tests).
    public var deniedAccounts: Set<String> = []

    public init() {}

    public var reads: Int { lock.withLock { _reads } }

    public func secret(for account: String) throws -> String? {
        try lock.withLock {
            _reads += 1
            if deniedAccounts.contains(account) { throw SecretStoreError(status: errSecAuthFailed) }
            return secrets[account]
        }
    }

    public func setSecret(_ value: String?, for account: String) throws {
        lock.withLock { secrets[account] = (value?.isEmpty ?? true) ? nil : value }
    }
}
