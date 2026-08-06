import Foundation
import Security

/// Stockage de la clé API dans le Keychain iOS — remplace le localStorage de la webapp.
/// La clé ne quitte jamais l'appareil et survit aux réinstallations de l'app.
enum KeychainStore {
    private static let service = "com.jeremiegalan.trident"
    private static let account = "mw_key"

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    static func getKey() -> String {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data,
              let s = String(data: data, encoding: .utf8) else { return "" }
        return s
    }

    static func setKey(_ key: String) {
        let data = Data(key.utf8)
        var query = baseQuery
        // supprime puis recrée : plus simple et sûr qu'un update conditionnel
        SecItemDelete(query as CFDictionary)
        guard !key.isEmpty else { return }
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(query as CFDictionary, nil)
    }
}
