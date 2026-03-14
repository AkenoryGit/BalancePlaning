//
//  UserService.swift
//  BalancePlaning
//
//  Created by Дмитрий Дудник on 09.02.2026.
//

import Foundation
import SwiftData

// для удобства, чтобы не писать каждый раз "currentUserId" и не допускать опечатки
enum UserDefaultKeys {
    static let currentUserId = "currentUserId"
}

class UserService {
    private let context: ModelContext
    
    init(context: ModelContext) {
        self.context = context
    }
    
    func updateDisplayName(_ user: User, displayName: String) {
        user.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        try? context.save()
    }

    // Проверяет текущий пароль, при совпадении обновляет на новый. Возвращает nil при успехе или текст ошибки.
    func changePassword(for user: User, current: String, new: String) -> String? {
        guard let data = try? KeychainManager.getPassword(for: user.id),
              let stored = String(data: data, encoding: .utf8) else {
            return "Ошибка чтения пароля"
        }
        guard stored == current else { return "Неверный текущий пароль" }
        guard new.count >= 8 else { return "Новый пароль менее 8 символов" }
        do {
            try KeychainManager.updatePassword(new, for: user.id)
            return nil
        } catch {
            return "Не удалось сохранить пароль"
        }
    }

    // узнаем текущего пользователя по сохраненному id пользователя в UserDefaults
    func getCurrentUser() -> User? {
        // вытаскиваем id текущего пользователя в формате String
        guard let uuidString = currentUserId() else {
            return nil
        }
        
        // ищем в SwiftData пользователей с таким же id
        let fetch = FetchDescriptor<User>(predicate: #Predicate { $0.id == uuidString })
        
        // пытаемся вернуть первого найденного в базе пользователя с таким id
        do {
            return try context.fetch(fetch).first
        } catch {
            print("Fetch error: \(error)")
            return nil
        }
    }
}
