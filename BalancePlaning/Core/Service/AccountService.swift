//
//  AccountService.swift
//  BalancePlaning
//
//  Created by Дмитрий Дудник on 12.02.2026.
//

import SwiftUI
import SwiftData

class AccountService {
    
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
    
    func dellAccount(_ account: Account) {
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
            let transactionFrom = foundUserOperations(type: .transaction, startDate: startDate, finishDate: finishDate)
                .filter { $0.fromAccount == account }
            
            let transactionTo = foundUserOperations(type: .transaction, startDate: startDate, finishDate: finishDate)
                .filter { $0.toAccount == account }
            
            let expenses = foundUserOperations(type: .expense, startDate: startDate, finishDate: finishDate)
                .filter { $0.fromAccount == account }
            
            let incomes = foundUserOperations(type: .income, startDate: startDate, finishDate: finishDate)
                .filter { $0.toAccount == account }
            
            let outgoing = transactionFrom.reduce(Decimal.zero) { $0 + $1.amount } +
                           expenses.reduce(Decimal.zero) { $0 + $1.amount }
            
            let incoming = transactionTo.reduce(Decimal.zero) { $0 + $1.amount } +
                           incomes.reduce(Decimal.zero) { $0 + $1.amount }
            
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
}
