//
//  TransactionService.swift
//  BalancePlaning
//
//  Created by Дмитрий Дудник on 26.02.2026.
//

import Foundation
import SwiftData

struct TransactionService {
    
    private let context: ModelContext
    
    init(context: ModelContext) {
        self.context = context
    }
    
    func addTransactions(from: Account, to: Account, amount: Decimal, toAmount: Decimal? = nil,
                         startDate: Date, endDate: Date? = nil,
                         interval: RecurringInterval? = nil, intervalDays: Int? = nil,
                         priority: TransactionPriority = .normal, note: String = "") {
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
                toAmount: toAmount,
                date: startDate,
                type: .transaction,
                priority: priority,
                note: note
            ))
        } else {
            guard let endDate = endDate, let interval = interval else {
                print("Не указана дата окончания для повторяющейся транзакции")
                return
            }
            let groupId = UUID()
            let days = generateDates(from: startDate, to: endDate, interval: interval, intervalDays: intervalDays)
            for day in days {
                newTransaction.append(Transaction(
                    fromAccount: from,
                    toAccount: to,
                    userId: curUserID,
                    amount: amount,
                    toAmount: toAmount,
                    date: day,
                    type: .transaction,
                    priority: priority,
                    recurringGroupId: groupId,
                    recurringInterval: interval,
                    recurringIntervalDays: intervalDays,
                    note: note
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
    
    func addExpense(from: Account, to: Category, amount: Decimal, startDate: Date, endDate: Date? = nil,
                    interval: RecurringInterval? = nil, intervalDays: Int? = nil,
                    priority: TransactionPriority = .normal, note: String = "") {
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
                type: .expense,
                priority: priority,
                note: note
            ))
        } else {
            guard let endDate = endDate, let interval = interval else {
                print("Не указана дата окончания для повторяющейся оплаты")
                return
            }
            let groupId = UUID()
            let days = generateDates(from: startDate, to: endDate, interval: interval, intervalDays: intervalDays)
            for day in days {
                newExpense.append(Transaction(
                    fromAccount: from,
                    toCategory: to,
                    userId: curUserID,
                    amount: amount,
                    date: day,
                    type: .expense,
                    priority: priority,
                    recurringGroupId: groupId,
                    recurringInterval: interval,
                    recurringIntervalDays: intervalDays,
                    note: note
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
                   interval: RecurringInterval? = nil, intervalDays: Int? = nil,
                   priority: TransactionPriority = .normal, note: String = "") {
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
                type: .income,
                priority: priority,
                note: note
            ))
        } else {
            guard let endDate = endDate, let interval = interval else {
                print("Не указана дата окончания для повторяющегося поступления")
                return
            }
            let groupId = UUID()
            let days = generateDates(from: startDate, to: endDate, interval: interval, intervalDays: intervalDays)
            for day in days {
                newIncome.append(Transaction(
                    fromCategory: from,
                    toAccount: to,
                    userId: curUserID,
                    amount: amount,
                    date: day,
                    type: .income,
                    priority: priority,
                    recurringGroupId: groupId,
                    recurringInterval: interval,
                    recurringIntervalDays: intervalDays,
                    note: note
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
    
    func addCorrection(account: Account, delta: Decimal, date: Date, comment: String = "") {
        guard let userId = currentUserId(), delta != 0 else { return }
        let t: Transaction
        if delta > 0 {
            t = Transaction(toAccount: account, userId: userId, amount: delta, date: date, type: .correction, comment: comment)
        } else {
            t = Transaction(fromAccount: account, userId: userId, amount: abs(delta), date: date, type: .correction, comment: comment)
        }
        context.insert(t)
        try? context.save()
    }

    func deleteTransaction(_ transaction: Transaction) {
        if let loanId = transaction.loanId {
            let txDate = transaction.date
            let txAmount = transaction.amount
            let predicate = #Predicate<LoanPayment> { $0.loanId == loanId }
            if let payments = try? context.fetch(FetchDescriptor<LoanPayment>(predicate: predicate)) {
                for p in payments where Calendar.current.isDate(p.date, inSameDayAs: txDate) && p.totalAmount == txAmount {
                    context.delete(p)
                }
            }
        }
        context.delete(transaction)

        do {
            try context.save()
            print("Транзакция \(transaction) была успешно удалена!")
        } catch {
            print("Ошибка удаления транзакции: \(error)")
        }
    }

    // удаляет все транзакции одной серии начиная с указанной даты
    func deleteFollowingTransactions(groupId: UUID, from date: Date) {
        guard let userId = currentUserId() else { return }
        let predicate = #Predicate<Transaction> { $0.userId == userId }
        let descriptor = FetchDescriptor<Transaction>(predicate: predicate)

        do {
            let all = try context.fetch(descriptor)
            let toDelete = all.filter { $0.recurringGroupId == groupId && $0.date >= date }
            for t in toDelete { context.delete(t) }
            try context.save()
            print("Удалено \(toDelete.count) повторяющихся транзакций")
        } catch {
            print("Ошибка удаления серии транзакций: \(error)")
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
