//
//  TransactionService.swift
//  BalancePlaning
//
//  Created by Дмитрий Дудник on 26.02.2026.
//

import SwiftUI
import SwiftData

struct TransactionService {
    
    private let context: ModelContext
    
    init(context: ModelContext) {
        self.context = context
    }
    
    func addTransactions(from: Account, to: Account, amount: Decimal, startDate: Date, endDate: Date? = nil,
                         interval: RecurringInterval? = nil, intervalDays: Int? = nil) {
        guard let curUserID = currentUserId() else {
            print("Пользователь не найден")
            return
        }
        var newTransaction: [Transaction] = []
        if interval == nil {
            newTransaction.append(Transaction(
                fromAccount: from,
                toAccount: to,
                userId: curUserID,
                amount: amount,
                date: startDate,
                type: .transaction
            ))
        } else {
            guard let endDate = endDate else {
                print("Не указана дата окончания для повторяющейся транзакции")
                return
            }
            guard let interval = interval else { return }
            let groupId = UUID()
            let days = generateDates(from: startDate, to: endDate, interval: interval)
            for day in days {
                newTransaction.append(Transaction(
                    fromAccount: from,
                    toAccount: to,
                    userId: curUserID,
                    amount: amount,
                    date: day,
                    type: .transaction,
                    recurringGroupId: groupId,
                    recurringInterval: interval,
                    recurringIntervalDays: intervalDays
                ))
            }
        }
        
        for transaction in newTransaction {
            context.insert(transaction) }
        
        do {
            try context.save()
            print("Перевод \(newTransaction) был успешно создан!")
        } catch {
            print("Ошибка создания перевода: \(error)")
            for transaction in newTransaction {
                context.delete(transaction) }
        }
    }
    
    func addExpenense(from: Account, to: Category, amount: Decimal, startDate: Date, endDate: Date? = nil,
                      interval: RecurringInterval? = nil, intervalDays: Int? = nil) {
        guard let curUserID = currentUserId() else {
            print("Пользователь не найден")
            return
        }
        var newExpense: [Transaction] = []
        if interval == nil {
            newExpense.append(Transaction(
            fromAccount: from,
            toCategory: to,
            userId: curUserID,
            amount: amount,
            date: startDate,
            type: .expense
        ))
        } else {
            guard let endDate = endDate else {
                print("Не указана дата окончания для повторяющейся оплаты")
                return
            }
            guard let interval = interval else { return }
            let groupId = UUID()
            let days = generateDates(from: startDate, to: endDate, interval: interval)
            for day in days {
                newExpense.append(Transaction(
                    fromAccount: from,
                    toCategory: to,
                    userId: curUserID,
                    amount: amount,
                    date: day,
                    type: .expense,
                    recurringGroupId: groupId,
                    recurringInterval: interval,
                    recurringIntervalDays: intervalDays
                ))
            }
        }
        
        for expense in newExpense {
            context.insert(expense) }
        
        do {
            try context.save()
            print("Оплата \(newExpense) была успешно создана!")
        } catch {
            print("Ошибка создания оплаты: \(error)")
            for expense in newExpense {
                context.delete(expense) }
        }
    }
    
    func addIncome(from: Category, to: Account, amount: Decimal, startDate: Date, endDate: Date? = nil,
                   interval: RecurringInterval? = nil, intervalDays: Int? = nil) {
        guard let curUserID = currentUserId() else {
            print("Пользователь не найден")
            return
        }
        var newIncome: [Transaction] = []
        if interval == nil {
            newIncome.append(Transaction(
                fromCategory: from,
                toAccount: to,
                userId: curUserID,
                amount: amount,
                date: startDate,
                type: .income
            ))
        } else {
            guard let endDate = endDate else {
                print("Не указана дата окончания для повторяющегося поступления")
                return
            }
            guard let interval = interval else { return }
            let groupId = UUID()
            let days = generateDates(from: startDate, to: endDate, interval: interval)
            for day in days {
                newIncome.append(Transaction(
                    fromCategory: from,
                    toAccount: to,
                    userId: curUserID,
                    amount: amount,
                    date: day,
                    type: .income,
                    recurringGroupId: groupId,
                    recurringInterval: interval,
                    recurringIntervalDays: intervalDays
                ))
            }
        }
        
        for income in newIncome {
            context.insert(income) }
        
        do {
            try context.save()
            print("Постепление \(newIncome) было успешно создано!")
        } catch {
            print("Ошибка создания поступления: \(error)")
            for income in newIncome {
                context.delete(income) }
        }
    }
    
    func dellTransaction(_ transaction: Transaction) {
        context.delete(transaction)
        
        do {
            try context.save()
            print("Транзакция \(transaction) была успешно удалена!")
        } catch {
            print("Ошибка удаления транзакции: \(error)")
        }
    }
    
    func generateDates(from startDate: Date, to endDate: Date, interval: RecurringInterval, intervalDays: Int? = nil) -> [Date] {
        var dates: [Date] = []
        var current = startDate
        
        while current <= endDate {
            dates.append(current)
            switch interval {
            case .daily:
                current = Calendar.current.date(byAdding: .day, value: 1, to: current) ?? current
            case .everyNDays:
                current = Calendar.current.date(byAdding: .day, value: intervalDays ?? 1, to: current) ?? current
            case .weekly:
                current = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: current) ?? current
            case .biweekly:
                current = Calendar.current.date(byAdding: .weekOfYear, value: 2, to: current) ?? current
            case .monthly:
                current = Calendar.current.date(byAdding: .month, value: 1, to: current) ?? current
            }
        }
        
        return dates
    }
}
