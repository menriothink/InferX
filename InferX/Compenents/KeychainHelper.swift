//
//  KeychainHelper.swift
//  InferX
//
//  Created by mingdw on 2025/5/22.
//

import Security
import SwiftUIX

struct KeychainHelper {
    @discardableResult
    static func save(key: String, value: String) -> Bool {
        let data = Data(value.utf8)

        let query: [String: Any] = [
            kSecClass as String       : kSecClassGenericPassword,
            kSecAttrAccount as String : key,
            kSecValueData as String   : data,
            kSecAttrAccessible as String : kSecAttrAccessibleWhenUnlocked
        ]

        let deleteStatus = SecItemDelete(query as CFDictionary)
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        
        if addStatus != errSecSuccess {
            print("[KeychainHelper] Failed to save key '\(key)', status: \(addStatus)")
            return false
        }
        return true
    }

    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String       : kSecClassGenericPassword,
            kSecAttrAccount as String : key,
            kSecReturnData as String  : true,
            kSecMatchLimit as String  : kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            print("[KeychainHelper] Failed to load key '\(key)', status: \(status)")
            return nil
        }

        return value
    }
    
    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
