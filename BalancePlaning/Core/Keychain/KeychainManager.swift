//
//  KeychainManager.swift
//  BalancePlaning
//
//  Created by Дмитрий Дудник on 05.02.2026.
//

import Foundation
import Security

enum KeychainError: Error {
    // ошибка с добавлением пароля к уже существующему аккаунту
    case duplicateItem
    // неизвестная ошибка с выяснением её статуса
    case unowned(status: OSStatus)
}

final class KeychainManager {
    // функция сохранения пароля
    static func save(password: String, id: UUID) throws {
        // преобразуем полученный String в кодировку пароля
        let data = password.data(using: .utf8)!
        // преобразуем id пользователя в String
        let key = id.uuidString
        
        // задаём кулючи для сохранения пароля в Keychain
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword, // выбираем что мы планируем сохранять именно пароль
            kSecAttrAccount: key, // связываем сохраненный пароль с id пользователя в формате String
            kSecValueData: data // пароль будет храниться в формате Data
        ]
        
        // присваиваем статусу результат добавление нового пароля через ранее созданный словарь, nil говорит что мне не требуется ссылка на созданный пароль
        let status = SecItemAdd(query as CFDictionary, nil)
        
        // проверяем есть ли дубликат сохранения пароля для выбранного аккаунта
        guard status != errSecDuplicateItem else {
            throw KeychainError.duplicateItem
        }
        // проверяем получилось ли сохранить пароль в Keychain
        guard status == errSecSuccess else {
            throw KeychainError.unowned(status: status)
        }
        print("Пароль успешно сохранен")
    }
    
    // сохранение ответа на секретный вопрос (ключ отличается от ключа пароля суффиксом)
    static func saveSecurityAnswer(_ answer: String, for id: UUID) throws {
        let data = answer.lowercased().trimmingCharacters(in: .whitespaces).data(using: .utf8)!
        let key = id.uuidString + "-securityAnswer"
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecValueData: data
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let updateQuery: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrAccount: key]
            SecItemUpdate(updateQuery as CFDictionary, [kSecValueData: data] as CFDictionary)
        } else if status != errSecSuccess {
            throw KeychainError.unowned(status: status)
        }
    }

    // получение ответа на секретный вопрос
    static func getSecurityAnswer(for id: UUID) -> String? {
        let key = id.uuidString + "-securityAnswer"
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData: kCFBooleanTrue as Any
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // функция обновления пароля
    static func updatePassword(_ newPassword: String, for id: UUID) throws {
        let data = newPassword.data(using: .utf8)!
        let key = id.uuidString

        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key
        ]
        let attributes: [CFString: Any] = [
            kSecValueData: data
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        guard status == errSecSuccess else {
            throw KeychainError.unowned(status: status)
        }
        print("Пароль успешно обновлён")
    }

    // функция получения пароля пользователя
    static func getPassword(for id: UUID) throws -> Data? {
        // преобразуем id пользователя в String
        let key = id.uuidString
        
        // задаём ключи для вытаскивания пароля из Keychain
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword, // нам нужен пароль
            kSecAttrAccount: key, // ищем по id пользователя
            kSecReturnData: kCFBooleanTrue as Any // при успехе, получаем пароль в виде Data
        ]
        
        // коробка куда положить полученный пароль
        var result: AnyObject?
        
        // ищем пароль, по заранее заданному словарю и кладем его в коробку result
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        // проверяем как прошла получение пароля, если не получилось, то показываем ошибку
        guard status == errSecSuccess else {
            throw KeychainError.unowned(status: status)
        }
        
        // возвращаем пароль в формате Data
        return result as? Data
    }
    
}
