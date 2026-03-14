//
//  AccountsSheetView.swift
//  BalancePlaning
//

import SwiftUI
import SwiftData

// MARK: - Шит со списком счетов

struct AccountsSheetView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Account.name) private var allAccounts: [Account]
    @Query(sort: \AccountGroup.name) private var allGroups: [AccountGroup]
    @Query private var allCurrencies: [Currency]

    private var accountService: AccountService { AccountService(context: context) }

    private var userAccounts: [Account] {
        guard let uid = currentUserId() else { return [] }
        return allAccounts.filter { $0.userId == uid }
    }
    private var userGroups: [AccountGroup] {
        guard let uid = currentUserId() else { return [] }
        return allGroups.filter { $0.userId == uid }
    }
    private var userCurrencies: [Currency] {
        guard let uid = currentUserId() else { return [] }
        return allCurrencies.filter { $0.userId == uid }
    }
    private func accounts(in group: AccountGroup) -> [Account] {
        userAccounts.filter { $0.groupId == group.id }
    }
    private var ungroupedAccounts: [Account] {
        userAccounts.filter { $0.groupId == nil }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(userGroups) { group in
                        let groupAccounts = accounts(in: group)
                        if !groupAccounts.isEmpty {
                            VStack(spacing: 0) {
                                HStack(spacing: 10) {
                                    Image(systemName: "folder.fill")
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.Colors.accent)
                                    Text(group.name)
                                        .font(.subheadline.bold())
                                    Spacer()
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)

                                ForEach(groupAccounts) { account in
                                    Divider().padding(.leading, 44)
                                    AccountBalanceRow(account: account,
                                                     balance: accountService.currentBalance(for: account),
                                                     customCurrencies: userCurrencies)
                                }
                            }
                            .cardStyle()
                        }
                    }

                    ForEach(ungroupedAccounts) { account in
                        AccountBalanceRow(account: account,
                                         balance: accountService.currentBalance(for: account),
                                         customCurrencies: userCurrencies)
                            .cardStyle()
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(AppTheme.Colors.pageBackground)
            .navigationTitle("Мои счета")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") { dismiss() }
                        .foregroundStyle(AppTheme.Colors.accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Строка счёта с балансом

struct AccountBalanceRow: View {
    let account: Account
    let balance: Decimal
    let customCurrencies: [Currency]

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "creditcard.fill")
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.accent)
                .frame(width: 34, height: 34)
                .background(AppTheme.Colors.accent.opacity(0.1))
                .clipShape(Circle())

            Text(account.name)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer()

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(balance, format: .number.precision(.fractionLength(0...2)))
                    .font(.subheadline.bold())
                    .foregroundStyle(balance >= 0 ? .primary : AppTheme.Colors.expense)
                Text(CurrencyInfo.symbol(for: account.currency, custom: customCurrencies))
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}
