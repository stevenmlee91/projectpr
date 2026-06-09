import Foundation
import Security

// MARK: - Keychain Helper
//
// Simple read / write / delete for string values.
// Used for Strava OAuth tokens — access tokens are sensitive and must not
// live in UserDefaults or @AppStorage.

enum KeychainHelper {

    private static let service = "com.milezero.MarathonPlanner"

    // MARK: - Save

    @discardableResult
    static func save(_ value: String, for key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        // Delete any existing entry first so we can add a fresh one
        delete(for: key)

        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecValueData:   data,
            // Accessible after first unlock — survives device restart without unlock
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock,
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    // MARK: - Load

    static func load(for key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecReturnData:  true,
            kSecMatchLimit:  kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8)
        else { return nil }
        return string
    }

    // MARK: - Delete

    @discardableResult
    static func delete(for key: String) -> Bool {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }

    // MARK: - Clear all Strava keys

    static func clearStrava() {
        delete(for: StravaKeys.accessToken)
        delete(for: StravaKeys.refreshToken)
        delete(for: StravaKeys.expiresAt)
    }
}

// MARK: - Strava key constants (file-private)

enum StravaKeys {
    static let accessToken  = "strava_access_token"
    static let refreshToken = "strava_refresh_token"
    static let expiresAt    = "strava_expires_at"     // stored as Unix timestamp string
}
