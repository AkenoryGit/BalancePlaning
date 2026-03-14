//
//  TransactionCard.swift
//  BalancePlaning
//

import SwiftUI
import SwiftData

// MARK: - Карточка транзакции

struct TransactionCard: View {
    let transaction: Transaction
    var allCategories: [Category] = []
    var allGroups: [AccountGroup] = []
    var showDate: Bool = false

    // Родительская категория для expense/income (nil если корневая)
    private var parentCategoryName: String? {
        let cat: Category?
        switch transaction.type {
        case .expense: cat = transaction.toCategory
        case .income:  cat = transaction.fromCategory
        default:       return nil
        }
        guard let parentId = cat?.parentId else { return nil }
        return allCategories.first { $0.id == parentId }?.name
    }

    // Имя группы счёта-источника (для expense/transfer) или счёта назначения (income)
    private func groupName(for account: Account?) -> String? {
        guard let gid = account?.groupId else { return nil }
        return allGroups.first { $0.id == gid }?.name
    }

    // Символ валюты счёта-источника (для отображения суммы списания)
    private var currencySymbol: String {
        switch transaction.type {
        case .income:      return CurrencyInfo.symbol(for: transaction.toAccount?.currency ?? "RUB")
        case .expense:     return CurrencyInfo.symbol(for: transaction.fromAccount?.currency ?? "RUB")
        case .transaction: return CurrencyInfo.symbol(for: transaction.fromAccount?.currency ?? "RUB")
        case .correction:  return CurrencyInfo.symbol(for: (transaction.fromAccount ?? transaction.toAccount)?.currency ?? "RUB")
        }
    }

    private var title: String {
        switch transaction.type {
        case .income:      return transaction.fromCategory?.name ?? "Пополнение"
        case .expense:     return transaction.toCategory?.name ?? "Расход"
        case .transaction: return "Перевод"
        case .correction:  return "Корректировка"
        }
    }

    private var subtitle: String {
        switch transaction.type {
        case .income:
            let accountName = accountLabel(transaction.toAccount)
            if let parent = parentCategoryName { return "\(parent) · \(accountName)" }
            return accountName
        case .expense:
            let accountName = accountLabel(transaction.fromAccount)
            if let parent = parentCategoryName { return "\(parent) · \(accountName)" }
            return accountName
        case .transaction:
            return "\(accountLabel(transaction.fromAccount)) → \(accountLabel(transaction.toAccount))"
        case .correction:
            let acc = transaction.toAccount ?? transaction.fromAccount
            return accountLabel(acc)
        }
    }

    private func accountLabel(_ account: Account?) -> String {
        guard let account else { return "" }
        if let g = groupName(for: account) { return "\(g) / \(account.name)" }
        return account.name
    }

    // Цвет корневой категории транзакции (для подсветки карточки)
    private var categoryTintColor: Color? {
        let cat: Category?
        switch transaction.type {
        case .expense: cat = transaction.toCategory
        case .income:  cat = transaction.fromCategory
        default:       return nil
        }
        guard let cat else { return nil }
        // Если это подкатегория — берём цвет родителя
        let rootId = cat.parentId ?? cat.id
        return allCategories.first { $0.id == rootId }.flatMap { CategoryColors.resolve($0.color) }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Цветная полоска приоритета
            (transaction.priority ?? .normal).stripeColor
                .frame(width: 4)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: AppTheme.cardRadius,
                        bottomLeadingRadius: AppTheme.cardRadius
                    )
                )

            HStack(spacing: 14) {
                // Иконка типа
                Image(systemName: transaction.type.icon)
                    .font(.title3)
                    .foregroundStyle(transaction.type.color)
                    .frame(width: 44, height: 44)
                    .background(transaction.type.color.opacity(0.12))
                    .clipShape(Circle())

                // Название и счёт
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if !transaction.note.isEmpty {
                        Text(transaction.note)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Сумма и время
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        if !transaction.type.amountPrefix.isEmpty {
                            Text(transaction.type.amountPrefix)
                                .font(.subheadline.bold())
                        }
                        Text(transaction.amount, format: .number.precision(.fractionLength(0...2)))
                            .font(.subheadline.bold())
                        Text(currencySymbol)
                            .font(.caption.bold())
                    }
                    .foregroundStyle(transaction.type.color)

                    if showDate {
                        Text(transaction.date, format: .dateTime
                            .day(.twoDigits)
                            .month(.twoDigits)
                            .year()
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(14)
        }
        .cardStyle(tint: categoryTintColor)
    }
}
