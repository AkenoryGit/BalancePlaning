//
//  KeychainManager.swift
//  BalancePlaning
//
//  Created by Дмитрий Дудник on 05.02.2026.
//

import SwiftUI
import Security

enum KeychainError: Error {
    case duplicateItem
    case unowned(status: OSStatus)
}

final class KeychainManager {
    static func save(password: String, id: UUID) throws {
        let data = password.data(using: .utf8)!
        let key = id.uuidString
        
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecValueData: data
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status != errSecDuplicateItem else {
            throw KeychainError.duplicateItem
        }
        
        guard status == errSecSuccess else {
            throw KeychainError.unowned(status: status)
        }
        if status == errSecSuccess {
            print("Пароль успешно сохранен")
        }
    }
    
    static func getPassword(for id: UUID) throws -> Data? {
        let key = id.uuidString
        
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData: kCFBooleanTrue as Any
        ]
        
        var result: AnyObject?
        
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            throw KeychainError.unowned(status: status)
        }
        
        return result as? Data
    }
    
}
