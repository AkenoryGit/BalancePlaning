//
//  Transaction.swift
//  BalancePlaning
//
//  Created by Дмитрий Дудник on 26.02.2026.
//

import Foundation
import SwiftData

@Model
class Transaction {
    var fromAccount: Account?
    var fromCategory: Category?
    var toAccount: Account?
    var toCategory: Category?
    var userId: UUID
    var amount: Decimal
    var toAmount: Decimal? = nil       // для конвертации валют: сумма зачисления в валюте toAccount
    var date: Date
    var type: TransactionType
    var priority: TransactionPriority? = nil

    var recurringGroupId: UUID?        // nil = обычная транзакция, UUID = часть расписания
    var recurringInterval: RecurringInterval?
    var recurringIntervalDays: Int?    // для everyNDays
    var note: String = ""
    var loanId: UUID? = nil            // non-nil → транзакция создана из платежа по кредиту

    init(fromAccount: Account? = nil, fromCategory: Category? = nil,
         toAccount: Account? = nil, toCategory: Category? = nil,
         userId: UUID, amount: Decimal, toAmount: Decimal? = nil,
         date: Date, type: TransactionType,
         priority: TransactionPriority? = nil,
         recurringGroupId: UUID? = nil,
         recurringInterval: RecurringInterval? = nil,
         recurringIntervalDays: Int? = nil,
         note: String = "",
         loanId: UUID? = nil) {
        self.fromAccount = fromAccount
        self.fromCategory = fromCategory
        self.toAccount = toAccount
        self.toCategory = toCategory
        self.userId = userId
        self.amount = amount
        self.toAmount = toAmount
        self.date = date
        self.type = type
        self.priority = priority
        self.recurringGroupId = recurringGroupId
        self.recurringInterval = recurringInterval
        self.recurringIntervalDays = recurringIntervalDays
        self.note = note
        self.loanId = loanId
    }
}

enum TransactionType: String, Codable {
    case transaction = "Transaction"
    case expense     = "Expense"
    case income      = "Income"
    case correction  = "Correction"

    var displayName: String {
        switch self {
        case .transaction: return "Перевод"
        case .expense:     return "Расход"
        case .income:      return "Пополнение"
        case .correction:  return "Корректировка"
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

enum TransactionPriority: String, Codable, CaseIterable {
    case mandatory = "Mandatory"
    case important = "Important"
    case normal    = "Normal"

    var displayName: String {
        switch self {
        case .mandatory: return "Обязательная"
        case .important: return "Важная"
        case .normal:    return "Обычная"
        }
    }

    var sortOrder: Int {
        switch self {
        case .mandatory: return 0
        case .important: return 1
        case .normal:    return 2
        }
    }
}
