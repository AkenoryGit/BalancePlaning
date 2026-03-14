//
//  EditTransactionView.swift
//  BalancePlaning
//

import SwiftUI
import SwiftData

struct EditTransactionView: View {
    @Environment(\.modelContext) private var context

    @Binding var isRootPresented: Bool
    let transaction: Transaction
    var onSaved: (@escaping () -> Void) -> Void = { _ in }

    var transactionService: TransactionService { TransactionService(context: context) }

    var body: some View {
        switch transaction.type {
        case .income:
            AddIncomeView(
                isRootPresented: $isRootPresented,
                fromCategory: transaction.fromCategory,
                toAccount: transaction.toAccount,
                amount: transaction.amount.description,
                date: transaction.date,
                recurringOperation: transaction.recurringGroupId != nil,
                interval: transaction.recurringInterval,
                intervalDays: String(transaction.recurringIntervalDays ?? 2),
                priority: transaction.priority ?? .normal,
                note: transaction.note,
                editingTransaction: transaction,
                onSaved: onSaved,
                transactionService: transactionService
            )
        case .expense:
            AddExpenseView(
                isRootPresented: $isRootPresented,
                fromAccount: transaction.fromAccount,
                toCategory: transaction.toCategory,
                amount: transaction.amount.description,
                date: transaction.date,
                recurringOperation: transaction.recurringGroupId != nil,
                interval: transaction.recurringInterval,
                intervalDays: String(transaction.recurringIntervalDays ?? 2),
                priority: transaction.priority ?? .normal,
                note: transaction.note,
                editingTransaction: transaction,
                onSaved: onSaved,
                transactionService: transactionService
            )
        default:
            AddTransactionView(
                isRootPresented: $isRootPresented,
                fromAccount: transaction.fromAccount,
                toAccount: transaction.toAccount,
                amount: transaction.amount.description,
                toAmount: transaction.toAmount?.description ?? "",
                date: transaction.date,
                recurringOperation: transaction.recurringGroupId != nil,
                interval: transaction.recurringInterval,
                intervalDays: String(transaction.recurringIntervalDays ?? 2),
                priority: transaction.priority ?? .normal,
                note: transaction.note,
                editingTransaction: transaction,
                onSaved: onSaved,
                transactionService: transactionService
            )
        }
    }
}
