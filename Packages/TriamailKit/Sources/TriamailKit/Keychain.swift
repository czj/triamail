import Foundation
import Security

/// Secrets (OAuth tokens, API keys) in the login keychain of this Mac.
public enum Keychain {
    public static let service = "Triamail"

    public enum Failure: Error, Equatable {
        case status(OSStatus)
    }

    public static func set(_ value: String, for account: String, service: String = service) throws {
        let query = baseQuery(account: account, service: service)
        let data = Data(value.utf8)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData] = data
            item[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlock
            let added = SecItemAdd(item as CFDictionary, nil)
            guard added == errSecSuccess else { throw Failure.status(added) }
        } else if status != errSecSuccess {
            throw Failure.status(status)
        }
    }

    public static func get(_ account: String, service: String = service) throws -> String? {
        var query = baseQuery(account: account, service: service)
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw Failure.status(status) }
        return String(data: data, encoding: .utf8)
    }

    public static func delete(_ account: String, service: String = service) throws {
        let status = SecItemDelete(baseQuery(account: account, service: service) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw Failure.status(status) }
    }

    private static func baseQuery(account: String, service: String) -> [CFString: Any] {
        [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: account]
    }
}
