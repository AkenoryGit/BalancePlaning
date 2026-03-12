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
