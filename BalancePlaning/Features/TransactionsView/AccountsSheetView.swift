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
    @Query private var allLoans: [Loan]
    @Query private var allLoanPayments: [LoanPayment]

    private var accountService: AccountService { AccountService(context: context) }
    private var loanService: LoanService { LoanService(context: context) }

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
    private var activeLoans: [Loan] {
        guard let uid = currentUserId() else { return [] }
        return allLoans.filter { $0.userId == uid && !$0.isArchived }
    }
    private func accounts(in group: AccountGroup) -> [Account] {
        userAccounts.filter { $0.groupId == group.id }
    }
    private var ungroupedAccounts: [Account] {
        userAccounts.filter { $0.groupId == nil }
    }
    private func remainingPrincipal(for loan: Loan) -> Decimal {
        let payments = allLoanPayments.filter { $0.loanId == loan.id }
        return loanService.remainingPrincipal(for: loan, payments: payments)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {

                    // MARK: Счета по группам
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
                                                     customCurrencies: userCurrencies,
                                                     showToggle: true,
                                                     onToggle: { toggleAccount(account) })
                                }
                            }
                            .cardStyle()
                        }
                    }

                    // MARK: Счета без группы
                    ForEach(ungroupedAccounts) { account in
                        AccountBalanceRow(account: account,
                                         balance: accountService.currentBalance(for: account),
                                         customCurrencies: userCurrencies,
                                         showToggle: true,
                                         onToggle: { toggleAccount(account) })
                            .cardStyle()
                    }

                    // MARK: Кредиты
                    if !activeLoans.isEmpty {
                        VStack(spacing: 0) {
                            HStack(spacing: 10) {
                                Image(systemName: "creditcard")
                                    .font(.subheadline)
                                    .foregroundStyle(Color(hex: "E74C3C"))
                                Text("Кредиты")
                                    .font(.subheadline.bold())
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)

                            ForEach(activeLoans) { loan in
                                Divider().padding(.leading, 44)
                                LoanBalanceRow(loan: loan,
                                              remaining: remainingPrincipal(for: loan),
                                              customCurrencies: userCurrencies,
                                              onToggle: { toggleLoan(loan) })
                            }
                        }
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

    private func toggleAccount(_ account: Account) {
        account.isIncludedInBalance.toggle()
        try? context.save()
    }

    private func toggleLoan(_ loan: Loan) {
        loan.isIncludedInBalance.toggle()
        try? context.save()
    }
}

// MARK: - Строка счёта с балансом

struct AccountBalanceRow: View {
    let account: Account
    let balance: Decimal
    let customCurrencies: [Currency]
    var showToggle: Bool = false
    var onToggle: (() -> Void)? = nil

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

            if showToggle {
                Image(systemName: account.isIncludedInBalance ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(account.isIncludedInBalance ? AppTheme.Colors.accent : Color.secondary.opacity(0.5))
                    .onTapGesture { onToggle?() }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

// MARK: - Строка кредита с остатком долга

struct LoanBalanceRow: View {
    let loan: Loan
    let remaining: Decimal
    let customCurrencies: [Currency]
    var onToggle: (() -> Void)? = nil

    private let loanRed = Color(hex: "E74C3C")

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "creditcard")
                .font(.subheadline)
                .foregroundStyle(loanRed)
                .frame(width: 34, height: 34)
                .background(loanRed.opacity(0.1))
                .clipShape(Circle())

            Text(loan.name)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer()

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(-remaining, format: .number.precision(.fractionLength(0...2)))
                    .font(.subheadline.bold())
                    .foregroundStyle(loanRed)
                Text(CurrencyInfo.symbol(for: loan.currency, custom: customCurrencies))
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            Image(systemName: loan.isIncludedInBalance ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(loan.isIncludedInBalance ? loanRed : Color.secondary.opacity(0.5))
                .onTapGesture { onToggle?() }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}
