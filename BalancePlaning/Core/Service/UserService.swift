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

struct UserService {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // узнаем текущего пользователя по сохраненному id пользователя в UserDefaults
    func getCurrentUser() -> User? {
        guard let userId = currentUserId() else {
            return nil
        }

        let fetch = FetchDescriptor<User>(predicate: #Predicate { $0.id == userId })
        
        // пытаемся вернуть первого найденного в базе пользователя с таким id
        do {
            return try context.fetch(fetch).first
        } catch {
            print("Fetch error: \(error)")
            return nil
        }
    }
}
