//
//  AccountService.swift
//  BalancePlaning
//
//  Created by Дмитрий Дудник on 12.02.2026.
//

import Foundation
import SwiftData

class AccountService {
    
    private let context: ModelContext
    
    init(context: ModelContext) {
        self.context = context
    }
    
    func addAccount(accountName: String, startBalance: Decimal, groupId: UUID? = nil, currency: String = "RUB") {
        guard let uuidString = currentUserId() else {
            print("Нет текущего пользователя")
            return
        }
        let newAccount = Account(id: UUID(), userId: uuidString, name: accountName, balance: startBalance, groupId: groupId, currency: currency)

        context.insert(newAccount)

        do {
            try context.save()
            print("Счет \(newAccount) был успешно создан!")
        } catch {
            print("Ошибка создания счета: \(error)")
            context.delete(newAccount)
        }
    }

    func updateAccount(_ account: Account, name: String, groupId: UUID?) {
        account.name = name
        account.groupId = groupId
        try? context.save()
    }
    
    func deleteAccount(_ account: Account) {
        context.delete(account)
        try? context.save()
    }

    /// Удаляет счёт и все транзакции, которые его используют
    func deleteAccountWithTransactions(_ account: Account) {
        let accountId = account.id
        let linked = fetchUserTransactions().filter {
            $0.fromAccount?.id == accountId || $0.toAccount?.id == accountId
        }
        for t in linked { context.delete(t) }
        context.delete(account)
        try? context.save()
    }

    /// Удаляет счёт, обнуляя ссылки на него в существующих транзакциях
    func deleteAccountDetachingTransactions(_ account: Account) {
        let accountId = account.id
        let linked = fetchUserTransactions().filter {
            $0.fromAccount?.id == accountId || $0.toAccount?.id == accountId
        }
        for t in linked {
            if t.fromAccount?.id == accountId { t.fromAccount = nil }
            if t.toAccount?.id == accountId   { t.toAccount = nil }
        }
        context.delete(account)
        try? context.save()
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
                .filter { ($0.type == .transaction || $0.type == .expense || $0.type == .correction) && $0.fromAccount?.id == account.id }
                .reduce(Decimal.zero) { $0 + $1.amount }

            // Для cross-currency переводов используем toAmount (сумма в валюте принимающего счёта)
            let incoming = filtered
                .filter { ($0.type == .transaction || $0.type == .income || $0.type == .correction) && $0.toAccount?.id == account.id }
                .reduce(Decimal.zero) { $0 + ($1.toAmount ?? $1.amount) }

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

    // Баланс сгруппированный по валютам (для BalanceCard)
    func totalBalancePerCurrency(at date: Date) -> [(code: String, amount: Decimal)] {
        let accounts = fetchUserAccounts().filter { $0.isIncludedInBalance }
        var dict: [String: Decimal] = [:]
        for account in accounts {
            dict[account.currency, default: .zero] += balance(for: account, at: date)
        }
        let predefinedOrder = CurrencyInfo.predefined.map { $0.code }
        return dict.sorted { a, b in
            let ai = predefinedOrder.firstIndex(of: a.key) ?? Int.max
            let bi = predefinedOrder.firstIndex(of: b.key) ?? Int.max
            return ai != bi ? ai < bi : a.key < b.key
        }.map { (code: $0.key, amount: $0.value) }
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
