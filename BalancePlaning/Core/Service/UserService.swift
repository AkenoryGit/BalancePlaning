//
//  UserService.swift
//  BalancePlaning
//
//  Created by Дмитрий Дудник on 09.02.2026.
//

import SwiftUI
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
