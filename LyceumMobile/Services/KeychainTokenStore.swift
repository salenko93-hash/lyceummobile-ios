import Foundation
import Security

enum KeychainTokenStore {
    private static let service = "ua.edu.cunl.lyceummobile.alerts.in.ua"
    private static let account = "uid81"

    private static var identity: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    static func load() -> String? {
        var query = identity
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let bytes = result as? Data
        else { return nil }
        return String(data: bytes, encoding: .utf8)
    }

    @discardableResult
    static func save(_ value: String) -> Bool {
        let token = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty, let bytes = token.data(using: .utf8) else { return false }
        var attributes = identity
        attributes[kSecValueData as String] = bytes
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status == errSecSuccess { return true }
        guard status == errSecDuplicateItem else { return false }
        let updates: [String: Any] = [kSecValueData as String: bytes]
        return SecItemUpdate(identity as CFDictionary, updates as CFDictionary) == errSecSuccess
    }

    @discardableResult
    static func clear() -> Bool {
        let result = SecItemDelete(identity as CFDictionary)
        return result == errSecSuccess || result == errSecItemNotFound
    }
}
