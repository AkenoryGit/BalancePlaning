//
//  TopTransactionsSection.swift
//  BalancePlaning
//

import SwiftUI

// MARK: - Секция крупнейших операций

struct TopTransactionsSection: View {
    let transactions: [Transaction]
    let allCategories: [Category]
    let customCurrencies: [Currency]

    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Крупнейшие операции")
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            if transactions.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 36))
                        .foregroundStyle(.quaternary)
                    Text("Нет операций за этот месяц")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .padding(.bottom, 8)
            } else {
                ForEach(Array(transactions.enumerated()), id: \.element.id) { index, transaction in
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            // Иконка типа
                            Image(systemName: transaction.type.icon)
                                .font(.title3)
                                .foregroundStyle(transaction.type.color)
                                .frame(width: 36, height: 36)

                            // Название и дата
                            VStack(alignment: .leading, spacing: 2) {
                                Text(transactionTitle(transaction))
                                    .font(.subheadline)
                                    .lineLimit(1)
                                Text(transaction.date.formatted(.dateTime
                                    .day()
                                    .month(.abbreviated)
                                    .locale(locale)))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            // Сумма
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text(transaction.amount, format: .number.precision(.fractionLength(0...2)))
                                    .font(.subheadline.bold())
                                    .foregroundStyle(transaction.type.color)
                                Text(transactionCurrencySymbol(transaction))
                                    .font(.caption.bold())
                                    .foregroundStyle(transaction.type.color.opacity(0.8))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)

                        if index < transactions.count - 1 {
                            Divider().padding(.leading, 64)
                        }
                    }
                }
                .padding(.bottom, 4)
            }
        }
    }

    // MARK: - Helpers

    private func transactionTitle(_ t: Transaction) -> String {
        switch t.type {
        case .income:
            if let cat = t.fromCategory {
                return cat.name
            }
            return "Пополнение"
        case .expense:
            if let cat = t.toCategory {
                return cat.name
            }
            return "Расход"
        case .transaction:
            return "Перевод"
        case .correction:
            return "Корректировка"
        }
    }

    private func transactionCurrencySymbol(_ t: Transaction) -> String {
        if let account = t.fromAccount {
            return CurrencyInfo.symbol(for: account.currency, custom: customCurrencies)
        }
        if let account = t.toAccount {
            return CurrencyInfo.symbol(for: account.currency, custom: customCurrencies)
        }
        return "₽"
    }
}
