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
    
    init(fromAccount: Account? = nil ,fromCategory: Category? = nil, toAccount: Account? = nil, toCategory: Category? = nil, userId: UUID, amount: Decimal, date: Date, type: TransactionType) {
        self.fromAccount = fromAccount
        self.fromCategory = fromCategory
        self.toAccount = toAccount
        self.toCategory = toCategory
        self.userId = userId
        self.amount = amount
        self.date = date
        self.type = type
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
