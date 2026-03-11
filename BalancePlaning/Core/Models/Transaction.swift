//
//  Transaction.swift
//  BalancePlaning
//
//  Created by Дмитрий Дудник on 26.02.2026.
//

import SwiftUI
import SwiftData

@Model
class Transaction {
    var fromAccount: Account?
    var fromCategory: Category?
    var toAccount: Account?
    var toCategory: Category?
    var userId: UUID
    var amount: Decimal
    var date: Date
    var type: TransactionType
    
    var recurringGroupId: UUID?        // nil = обычная транзакция, UUID = часть расписания
    var recurringInterval: RecurringInterval?
    var recurringIntervalDays: Int?    // для everyNDays
    
    init(fromAccount: Account? = nil, fromCategory: Category? = nil,
         toAccount: Account? = nil, toCategory: Category? = nil,
         userId: UUID, amount: Decimal, date: Date, type: TransactionType,
         recurringGroupId: UUID? = nil,
         recurringInterval: RecurringInterval? = nil,
         recurringIntervalDays: Int? = nil) {
        self.fromAccount = fromAccount
        self.fromCategory = fromCategory
        self.toAccount = toAccount
        self.toCategory = toCategory
        self.userId = userId
        self.amount = amount
        self.date = date
        self.type = type
        self.recurringGroupId = recurringGroupId
        self.recurringInterval = recurringInterval
        self.recurringIntervalDays = recurringIntervalDays
    }
}

enum TransactionType: String, Codable {
    case transaction = "Transaction"
    case expense = "Expense"
    case income = "Income"
    
    var displayName: String {
        switch self {
        case .transaction: return "Перевод"
        case .expense: return "Расход"
        case .income: return "Пополнение"
        }
    }
}

enum RecurringInterval: String, Codable, CaseIterable {
    case daily
    case everyNDays
    case weekly
    case biweekly
    case monthly
    
    var displayName: String {
        switch self {
        case .daily: return "Ежедневно"
        case .everyNDays: return "Каждые Х дней"
        case .weekly: return "Каждую неделю"
        case .biweekly: return "Каждые 2 недели"
        case .monthly: return "Каждый месяц"
        }
    }
}
