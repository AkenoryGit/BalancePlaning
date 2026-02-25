//
//  AccountService.swift
//  BalancePlaning
//
//  Created by Дмитрий Дудник on 12.02.2026.
//

import SwiftUI
import SwiftData

class AccountService {
    @Query(sort: \Account.userId) var accounts:[Account] = []
    
    private let context: ModelContext
    
    init(context: ModelContext) {
        self.context = context
    }
    
    func addAccount(accountName: String, startBalance: Decimal) {
        guard let uuidString = UserDefaults.standard.string(forKey: UserDefaultKeys.currentUserId),
              let userId = UUID(uuidString: uuidString) else {
            print("Нет текущего пользователя")
            return
        }
        let newAccount = Account(id: UUID(), userId: userId, name: accountName, balance: startBalance)
        
        context.insert(newAccount)
        
        do {
            try context.save()
            print("Счет \(newAccount) был успешно создан!")
        } catch {
            print("Ошибка создания счета: \(error)")
            context.delete(newAccount)
        }
    }
    
    func dellAccount(_ account: Account) {
        context.delete(account)
        
        do {
            try context.save()
            print("Счет \(account) был успешно удален!")
        } catch {
            print("Ошибка удаления счета: \(error)")
        }
    }
}
