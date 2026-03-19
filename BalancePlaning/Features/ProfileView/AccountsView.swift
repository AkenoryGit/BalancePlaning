//
//  AccountsView.swift
//  BalancePlaning
//

import SwiftUI
import SwiftData

// MARK: - AccountsView

struct AccountsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Account.name) private var allAccounts: [Account]
    @Query(sort: \AccountGroup.name) private var allGroups: [AccountGroup]
    @Query private var allCurrencies: [Currency]

    @State private var selectedAccount: Account?
    @State private var selectedGroup: AccountGroup?
    @State private var showAddAccount = false
    @State private var showAddGroup = false
    @State private var collapsedGroupIds: Set<UUID> = []

    private var accountService: AccountService { AccountService(context: context) }

    private var userCurrencies: [Currency] {
        guard let uid = currentUserId() else { return [] }
        return allCurrencies.filter { $0.userId == uid }
    }
    private var userAccounts: [Account] {
        guard let uid = currentUserId() else { return [] }
        return allAccounts.filter { $0.userId == uid }
    }
    private var userGroups: [AccountGroup] {
        guard let uid = currentUserId() else { return [] }
        return allGroups.filter { $0.userId == uid }
    }
    private func accounts(in group: AccountGroup) -> [Account] {
        userAccounts.filter { $0.groupId == group.id }
    }
    private var ungroupedAccounts: [Account] {
        userAccounts.filter { $0.groupId == nil }
    }
    private func groupTotals(_ group: AccountGroup) -> [(code: String, amount: Decimal)] {
        var dict: [String: Decimal] = [:]
        for acc in accounts(in: group) {
            dict[acc.currency, default: .zero] += accountService.currentBalance(for: acc)
        }
        let predefinedOrder = CurrencyInfo.predefined.map { $0.code }
        return dict.sorted { a, b in
            let ai = predefinedOrder.firstIndex(of: a.key) ?? Int.max
            let bi = predefinedOrder.firstIndex(of: b.key) ?? Int.max
            return ai != bi ? ai < bi : a.key < b.key
        }.map { (code: $0.key, amount: $0.value) }
    }

    var body: some View {
        VStack(spacing: 8) {
            // Заголовок секции
            HStack {
                Text("Мои счета").font(.headline).padding(.leading, 20)
                Spacer()
                Menu {
                    Button { showAddAccount = true } label: { Label("Новый счёт", systemImage: "creditcard.fill") }
                    Button { showAddGroup = true }   label: { Label("Новая группа", systemImage: "folder.fill") }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus").font(.caption.bold())
                        Text("Добавить").font(.subheadline)
                    }
                    .foregroundStyle(AppTheme.Colors.accent)
                }
                .padding(.trailing, 20)
            }

            if userAccounts.isEmpty && userGroups.isEmpty {
                ContentUnavailableView("Нет счетов", systemImage: "wallet.bifold").padding(.top, 20)
            } else {
                ForEach(userGroups) { group in
                    AccountGroupSection(
                        group: group,
                        accounts: accounts(in: group),
                        totals: groupTotals(group),
                        customCurrencies: userCurrencies,
                        isExpanded: !collapsedGroupIds.contains(group.id),
                        onToggle: {
                            withAnimation(.spring(response: 0.3)) {
                                if collapsedGroupIds.contains(group.id) {
                                    collapsedGroupIds.remove(group.id)
                                } else {
                                    collapsedGroupIds.insert(group.id)
                                }
                            }
                        },
                        onGroupEdit: { selectedGroup = group },
                        onAccountTap: { selectedAccount = $0 },
                        accountBalance: { accountService.currentBalance(for: $0) }
                    )
                    .padding(.horizontal, 20)
                }
                ForEach(ungroupedAccounts) { account in
                    AccountRowCard(account: account, balance: accountService.currentBalance(for: account), customCurrencies: userCurrencies)
                        .padding(.horizontal, 20)
                        .onTapGesture { selectedAccount = account }
                }
            }
        }
        .sheet(item: $selectedAccount) { account in
            AccountDetailSheet(account: account, groups: userGroups, selectedAccount: $selectedAccount)
        }
        .sheet(item: $selectedGroup) { group in
            GroupDetailSheet(group: group, selectedGroup: $selectedGroup)
        }
        .sheet(isPresented: $showAddAccount) { AddAccountSheet(groups: userGroups) }
        .sheet(isPresented: $showAddGroup)   { AddGroupSheet() }
    }
}

// MARK: - Группа счетов

struct AccountGroupSection: View {
    let group: AccountGroup
    let accounts: [Account]
    let totals: [(code: String, amount: Decimal)]
    let customCurrencies: [Currency]
    let isExpanded: Bool
    let onToggle: () -> Void
    let onGroupEdit: () -> Void
    let onAccountTap: (Account) -> Void
    let accountBalance: (Account) -> Decimal

    var body: some View {
        VStack(spacing: 0) {
            // Заголовок группы — тапается для сворачивания
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    Image(systemName: "folder.fill")
                        .font(.subheadline).foregroundStyle(AppTheme.Colors.accent)
                        .frame(width: 34, height: 34)
                        .background(AppTheme.Colors.accent.opacity(0.1)).clipShape(Circle())

                    Text(group.name).font(.subheadline.bold()).foregroundStyle(.primary)
                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        ForEach(totals, id: \.code) { entry in
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text(entry.amount, format: .number.precision(.fractionLength(0...2)))
                                    .font(.subheadline.bold()).foregroundStyle(AppTheme.Colors.accent)
                                Text(CurrencyInfo.symbol(for: entry.code, custom: customCurrencies))
                                    .font(.caption.bold()).foregroundStyle(AppTheme.Colors.accent.opacity(0.8))
                            }
                        }
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption).foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.spring(response: 0.3), value: isExpanded)

                    Button(action: onGroupEdit) {
                        Image(systemName: "ellipsis.circle").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            // Счета внутри группы
            if isExpanded {
                ForEach(accounts) { account in
                    Divider().padding(.leading, 60)
                    Button { onAccountTap(account) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: account.icon.isEmpty ? "creditcard" : account.icon)
                                .font(.subheadline).foregroundStyle(AppTheme.Colors.accent)
                                .frame(width: 34, height: 34)

                            Text(account.name).font(.subheadline).foregroundStyle(.primary)
                            Spacer()

                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text(accountBalance(account), format: .number.precision(.fractionLength(0...2)))
                                    .font(.subheadline.bold()).foregroundStyle(.primary)
                                Text(CurrencyInfo.symbol(for: account.currency, custom: customCurrencies))
                                    .font(.caption.bold()).foregroundStyle(.secondary)
                            }
                            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .cardStyle()
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }
}

// MARK: - Строка счёта (без группы)

struct AccountRowCard: View {
    let account: Account
    let balance: Decimal
    var customCurrencies: [Currency] = []

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: account.icon.isEmpty ? "creditcard.fill" : account.icon)
                .font(.title3).foregroundStyle(AppTheme.Colors.accent)
                .frame(width: 40, height: 40)
                .background(AppTheme.Colors.accent.opacity(0.1)).clipShape(Circle())

            Text(account.name).font(.headline).foregroundStyle(.primary)
            Spacer()

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(balance, format: .number.precision(.fractionLength(0...2)))
                    .font(.subheadline.bold()).foregroundStyle(AppTheme.Colors.accent)
                Text(CurrencyInfo.symbol(for: account.currency, custom: customCurrencies))
                    .font(.caption.bold()).foregroundStyle(AppTheme.Colors.accent.opacity(0.8))
            }
            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(14)
        .cardStyle()
    }
}
