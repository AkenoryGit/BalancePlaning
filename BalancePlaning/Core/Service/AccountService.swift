//
//  AccountService.swift
//  BalancePlaning
//
//  Created by Дмитрий Дудник on 12.02.2026.
//

import Foundation
import SwiftData

struct AccountService {
    
    private let context: ModelContext
    
    init(context: ModelContext) {
        self.context = context
    }
    
    func addAccount(accountName: String, startBalance: Decimal) {
        guard let uuidString = currentUserId() else {
            print("Нет текущего пользователя")
            return
        }
        let newAccount = Account(id: UUID(), userId: uuidString, name: accountName, balance: startBalance)
        
        context.insert(newAccount)
        
        do {
            try context.save()
            print("Счет \(newAccount) был успешно создан!")
        } catch {
            print("Ошибка создания счета: \(error)")
            context.delete(newAccount)
        }
    }
    
    func deleteAccount(_ account: Account) {
        context.delete(account)
        
        do {
            try context.save()
            print("Счет \(account) был успешно удален!")
        } catch {
            print("Ошибка удаления счета: \(error)")
        }
    }
    
    private func fetchUserTransactions() -> [Transaction] {
            guard let userId = currentUserId() else {
                return []
            }
            
            let predicate = #Predicate<Transaction> { $0.userId == userId }
            let sort = [SortDescriptor(\Transaction.date)]
            let descriptor = FetchDescriptor<Transaction>(predicate: predicate, sortBy: sort)
            
            do {
                return try context.fetch(descriptor)
            } catch {
                print("Ошибка загрузки транзакций: \(error)")
                return []
            }
        }
        
        func foundUserOperations(type: TransactionType, startDate: Date?, finishDate: Date) -> [Transaction] {
            let transactions = fetchUserTransactions()  // один fetch на все
            
            let filtered: [Transaction]
            
            if let startDate = startDate {
                filtered = transactions.filter { $0.type == type && $0.date >= startDate && $0.date <= finishDate }
            } else {
                filtered = transactions.filter { $0.type == type && $0.date <= finishDate }
            }
            
            return filtered.sorted { $0.date < $1.date }
        }
        
        func collectAmountTransactions(account: Account, startDate: Date?, finishDate: Date) -> Decimal {
            let all = fetchUserTransactions()

            let filtered: [Transaction]
            if let startDate = startDate {
                filtered = all.filter { $0.date >= startDate && $0.date <= finishDate }
            } else {
                filtered = all.filter { $0.date <= finishDate }
            }

            let outgoing = filtered
                .filter { ($0.type == .transaction || $0.type == .expense) && $0.fromAccount == account }
                .reduce(Decimal.zero) { $0 + $1.amount }

            let incoming = filtered
                .filter { ($0.type == .transaction || $0.type == .income) && $0.toAccount == account }
                .reduce(Decimal.zero) { $0 + $1.amount }

            return incoming - outgoing
        }
    
    // Баланс на текущий момент (для отображения везде по умолчанию)
    func currentBalance(for account: Account) -> Decimal {
        account.balance + collectAmountTransactions(
            account: account,
            startDate: nil,
            finishDate: Date.now
        )
    }

    // Баланс на произвольную дату (для экрана аналитики)
    func balance(for account: Account, at date: Date) -> Decimal {
        account.balance + collectAmountTransactions(
            account: account,
            startDate: nil,
            finishDate: date
        )
    }
    
    func totalBalance(at date: Date) -> Decimal {
        let accounts = fetchUserAccounts()
        return accounts.reduce(Decimal.zero) { $0 + balance(for: $1, at: date) }
    }
    
    private func fetchUserAccounts() -> [Account] {
        guard let userId = currentUserId() else { return [] }
        
        let predicate = #Predicate<Account> { $0.userId == userId }
        let descriptor = FetchDescriptor<Account>(predicate: predicate)
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("Ошибка загрузки счетов: \(error)")
            return []
        }
    }
}
