//
//  TransactionsView.swift
//  BalancePlaning
//

import SwiftUI
import SwiftData

// MARK: - Главный экран (Dashboard)

struct TransactionsView: View {
    @Environment(\.modelContext) var context
    @Environment(\.locale) private var locale
    @State private var date: Date = Date.now
    @State private var isPresented: Bool = false
    @State private var showDatePicker: Bool = false
    @State private var viewMode: TransactionViewMode = .day
    @State private var filter: TransactionFilter = TransactionFilter()
    @State private var showFilterSheet: Bool = false
    @State private var selectedTransaction: Transaction?
    @State private var showAccountsSheet = false
    @State private var pendingDeleteId: PersistentIdentifier?
    @State private var pendingDeleteClosure: (() -> Void)?

    // Swipe selection
    @State private var selectedIds: Set<PersistentIdentifier> = []
    @State private var showDeleteAlert: Bool = false
    @State private var showBatchDeleteAlert: Bool = false

    @Query private var allTransactions: [Transaction]
    @Query private var allCurrencies: [Currency]
    @Query private var allCategories: [Category]
    @Query private var allGroups: [AccountGroup]
    @Query private var allAccounts: [Account]
    @Query private var allLoans: [Loan]
    @Query private var allLoanPayments: [LoanPayment]

    private var isSelecting: Bool { !selectedIds.isEmpty }

    private var userCurrencies: [Currency] {
        guard let uid = currentUserId() else { return [] }
        return allCurrencies.filter { $0.userId == uid }
    }
    private var userCategories: [Category] {
        guard let uid = currentUserId() else { return [] }
        return allCategories.filter { $0.userId == uid }
    }
    private var userGroups: [AccountGroup] {
        guard let uid = currentUserId() else { return [] }
        return allGroups.filter { $0.userId == uid }
    }

    private var userTransactions: [Transaction] {
        guard let userId = currentUserId() else { return [] }
        return allTransactions.filter { $0.userId == userId }
    }

    private var userAccounts: [Account] {
        guard let uid = currentUserId() else { return [] }
        return allAccounts.filter { $0.userId == uid }
    }

    private var hasNoAccounts: Bool { userAccounts.isEmpty }

    private var dailyTransactions: [Transaction] {
        userTransactions
            .filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.date > $1.date }
    }

    private var periodTransactions: [Transaction] {
        userTransactions.filter { filter.matches($0) }
    }

    private var shownTransactions: [Transaction] {
        let base: [Transaction]
        switch viewMode {
        case .day:    base = dailyTransactions
        case .all:    base = userTransactions
        case .period: base = periodTransactions
        }
        return base.filter { $0.persistentModelID != pendingDeleteId }.sorted {
            switch viewMode {
            case .day:
                let lhs = ($0.priority ?? .normal).sortOrder
                let rhs = ($1.priority ?? .normal).sortOrder
                if lhs != rhs { return lhs < rhs }
                return $0.date > $1.date
            case .all, .period:
                return $0.date < $1.date
            }
        }
    }

    private var dailyIncomeByCurrency: [(code: String, amount: Decimal)] {
        var dict: [String: Decimal] = [:]
        for t in dailyTransactions where t.type == .income {
            dict[t.toAccount?.currency ?? "RUB", default: .zero] += t.amount
        }
        return dict.map { (code: $0.key, amount: $0.value) }.sorted { $0.amount > $1.amount }
    }

    private var dailyExpenseByCurrency: [(code: String, amount: Decimal)] {
        var dict: [String: Decimal] = [:]
        for t in dailyTransactions where t.type == .expense {
            dict[t.fromAccount?.currency ?? "RUB", default: .zero] += t.amount
        }
        return dict.map { (code: $0.key, amount: $0.value) }.sorted { $0.amount > $1.amount }
    }

    private var combinedBalances: [(code: String, amount: Decimal)] {
        guard let uid = currentUserId() else { return [] }
        var dict: [String: Decimal] = [:]

        let includedAccounts = allAccounts.filter { $0.userId == uid && $0.isIncludedInBalance }
        let cal = Calendar.current
        let endOfDay = cal.startOfDay(for: date).addingTimeInterval(86400)
        for account in includedAccounts {
            let outgoing = allTransactions
                .filter { $0.date < endOfDay
                    && ($0.type == .transaction || $0.type == .expense || $0.type == .correction)
                    && $0.fromAccount?.id == account.id }
                .reduce(Decimal.zero) { $0 + $1.amount }
            let incoming = allTransactions
                .filter { $0.date < endOfDay
                    && ($0.type == .transaction || $0.type == .income || $0.type == .correction)
                    && $0.toAccount?.id == account.id }
                .reduce(Decimal.zero) { $0 + ($1.toAmount ?? $1.amount) }
            dict[account.currency, default: .zero] += account.balance + incoming - outgoing
        }

        let loanSvc = LoanService(context: context)
        let userLoans = allLoans.filter { $0.userId == uid && !$0.isArchived && $0.isIncludedInBalance }
        for loan in userLoans {
            let payments = allLoanPayments.filter { $0.loanId == loan.id && $0.date < endOfDay }
            let remaining = loanSvc.remainingPrincipal(for: loan, payments: payments)
            dict[loan.currency, default: .zero] -= remaining
        }

        let predefinedOrder = CurrencyInfo.predefined.map { $0.code }
        return dict.sorted { a, b in
            let ai = predefinedOrder.firstIndex(of: a.key) ?? Int.max
            let bi = predefinedOrder.firstIndex(of: b.key) ?? Int.max
            return ai != bi ? ai < bi : a.key < b.key
        }.map { (code: $0.key, amount: $0.value) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    if hasNoAccounts {
                        OnboardingCard()
                            .padding(.horizontal)
                            .padding(.top, 20)
                    } else {
                        BalanceCard(
                            balances: combinedBalances,
                            date: $date,
                            showNavigation: viewMode == .day,
                            customCurrencies: userCurrencies,
                            onDateTap: { showDatePicker = true },
                            onBalanceTap: { showAccountsSheet = true }
                        )
                        .padding(.horizontal)

                        if viewMode == .day {
                            HStack(alignment: .top, spacing: 12) {
                                MultiCurrencyPill(label: "Доходы", entries: dailyIncomeByCurrency,
                                                 color: AppTheme.Colors.income, customCurrencies: userCurrencies)
                                MultiCurrencyPill(label: "Расходы", entries: dailyExpenseByCurrency,
                                                 color: AppTheme.Colors.expense, customCurrencies: userCurrencies)
                            }
                            .padding(.horizontal)
                        }

                        Picker("", selection: $viewMode) {
                            ForEach(TransactionViewMode.allCases, id: \.self) { mode in
                                Text(LocalizedStringKey(mode.label)).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)

                        if viewMode == .period {
                            Button { showFilterSheet = true } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                        .foregroundStyle(AppTheme.Colors.accent)
                                    VStack(alignment: .leading, spacing: 1) {
                                        HStack(spacing: 4) {
                                            Text(filter.startDate, format: .dateTime.day(.twoDigits).month(.twoDigits).year().locale(locale))
                                            Text("—")
                                            Text(filter.endDate, format: .dateTime.day(.twoDigits).month(.twoDigits).year().locale(locale))
                                        }
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.primary)
                                        if filter.activeFilterCount > 0 {
                                            Text(filterCountLabel(filter.activeFilterCount))
                                                .font(.caption)
                                                .foregroundStyle(AppTheme.Colors.accent)
                                        }
                                    }
                                    Spacer()
                                    Text("Изменить")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.Colors.accent)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .cardStyle()
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal)
                        }

                        if shownTransactions.isEmpty {
                            EmptyTransactionsPlaceholder(viewMode: viewMode)
                                .padding(.top, 40)
                        } else {
                            LazyVStack(spacing: 10) {
                                ForEach(shownTransactions) { transaction in
                                    SwipeableTransactionRow(
                                        transaction: transaction,
                                        allCategories: userCategories,
                                        allGroups: userGroups,
                                        showDate: viewMode != .day,
                                        isSelected: selectedIds.contains(transaction.persistentModelID),
                                        onTap: {
                                            if isSelecting {
                                                withAnimation(.spring(duration: 0.2)) {
                                                    toggleSelection(transaction)
                                                }
                                            } else {
                                                selectedTransaction = transaction
                                            }
                                        },
                                        onDelete: {
                                            let service = TransactionService(context: context)
                                            pendingDeleteClosure = { service.deleteTransaction(transaction) }
                                            pendingDeleteId = transaction.persistentModelID
                                            showDeleteAlert = true
                                        },
                                        onToggleSelect: {
                                            withAnimation(.spring(duration: 0.2)) {
                                                toggleSelection(transaction)
                                            }
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
            .background(AppTheme.Colors.pageBackground)
            .navigationTitle("Кошелёк")
            .navigationBarTitleDisplayMode(.large)
            .overlay(alignment: .bottomTrailing) {
                if !hasNoAccounts && !isSelecting {
                    Button { isPresented = true } label: {
                        Image(systemName: "plus")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                            .frame(width: 58, height: 58)
                            .background(
                                LinearGradient(
                                    colors: [AppTheme.Colors.accent, AppTheme.Colors.accentSecondary],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Circle())
                            .shadow(color: AppTheme.Colors.accent.opacity(0.4), radius: 10, x: 0, y: 5)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .safeAreaInset(edge: .bottom) {
                if isSelecting {
                    selectionBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.3), value: isSelecting)
        }
        .sheet(isPresented: $isPresented) {
            TransactionsCategoryView(isRootPresented: $isPresented)
        }
        .sheet(item: $selectedTransaction) { transaction in
            TransactionDetailView(transaction: transaction, selectedTransaction: $selectedTransaction)
        }
        .sheet(isPresented: $showDatePicker) {
            DatePickerSheet(date: $date, onShowAll: { viewMode = .all })
        }
        .sheet(isPresented: $showFilterSheet) {
            FilterSheet(filter: $filter)
        }
        .sheet(isPresented: $showAccountsSheet) {
            AccountsSheetView()
        }
        // Алерт: удаление одной операции (свайп вправо-влево)
        .alert("Удалить операцию?", isPresented: $showDeleteAlert) {
            Button("Удалить", role: .destructive) {
                pendingDeleteClosure?()
                pendingDeleteClosure = nil
                pendingDeleteId = nil
            }
            Button("Отмена", role: .cancel) {
                pendingDeleteId = nil
                pendingDeleteClosure = nil
            }
        } message: {
            Text("Операция удалится безвозвратно")
        }
        // Алерт: удаление выбранных операций
        .alert("Удалить выбранные операции?", isPresented: $showBatchDeleteAlert) {
            Button("Удалить", role: .destructive) {
                deleteSelected()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text(batchDeleteMessage)
        }
        .onChange(of: viewMode) { _, _ in
            date = Date()
            selectedIds.removeAll()
        }
    }

    // MARK: - Selection bar

    private var selectionBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 16) {
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        selectedIds.removeAll()
                    }
                } label: {
                    Text("Отменить")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(selectionCountLabel)
                    .font(.subheadline.bold())

                Spacer()

                Button {
                    showBatchDeleteAlert = true
                } label: {
                    Label("Удалить", systemImage: "trash")
                        .foregroundStyle(.red)
                        .font(.subheadline.bold())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .background(Color(.secondarySystemGroupedBackground))
    }

    // MARK: - Helpers

    private func toggleSelection(_ transaction: Transaction) {
        if selectedIds.contains(transaction.persistentModelID) {
            selectedIds.remove(transaction.persistentModelID)
        } else {
            selectedIds.insert(transaction.persistentModelID)
        }
    }

    private func deleteSelected() {
        let service = TransactionService(context: context)
        for transaction in shownTransactions where selectedIds.contains(transaction.persistentModelID) {
            service.deleteTransaction(transaction)
        }
        selectedIds.removeAll()
    }

    private var selectionCountLabel: String {
        let n = selectedIds.count
        let bundle = AppSettings.shared.bundle
        if bundle != Bundle.main {
            return "\(n) selected"
        }
        let suffix: String
        if n == 1 { suffix = "а" } else if n < 5 { suffix = "ы" } else { suffix = "" }
        return "Выбрано \(n) операци\(suffix == "" ? "й" : suffix)"
    }

    private var batchDeleteMessage: String {
        let n = selectedIds.count
        let bundle = AppSettings.shared.bundle
        if bundle != Bundle.main {
            return "\(n) operation\(n == 1 ? "" : "s") will be deleted permanently"
        }
        let suffix: String
        if n == 1 { suffix = "я" } else if n < 5 { suffix = "и" } else { suffix = "й" }
        return "\(n) операци\(suffix) удалятся безвозвратно"
    }

    private func filterCountLabel(_ n: Int) -> String {
        let bundle = AppSettings.shared.bundle
        if bundle != Bundle.main {
            return "\(n) more filter\(n == 1 ? "" : "s")"
        }
        let suffix: String
        if n == 1 { suffix = "" } else if n < 5 { suffix = "а" } else { suffix = "ов" }
        return "Ещё \(n) фильтр\(suffix)"
    }
}
