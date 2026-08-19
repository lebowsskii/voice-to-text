import Foundation
import Security

/// Persists the Gemini API key in the Keychain. Unlike `SettingsStore`, this
/// never touches `UserDefaults` — a secret has no business sitting in a
/// plist that syncs, backs up, and gets read by anything that can open the
/// app's container.
final class GeminiAPIKeyStore {
    private let service: String
    private let account = "api-key"

    init(service: String = "com.lebowsskii.voicetotext.gemini") {
        self.service = service
    }

    func get() -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func set(_ key: String) {
        let data = Data(key.utf8)
        let query = baseQuery()

        if SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess {
            SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        } else {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    func clear() {
        SecItemDelete(baseQuery() as CFDictionary)
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
