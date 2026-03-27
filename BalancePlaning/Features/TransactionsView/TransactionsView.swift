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
    @EnvironmentObject private var autoSync: CloudKitAutoSyncManager
    @Environment(TransactionSelectionModel.self) private var selectionModel
    @State private var date: Date = Date.now
    @State private var showDatePicker: Bool = false
    @State private var viewMode: TransactionViewMode = .day
    @State private var filter: TransactionFilter = TransactionFilter()
    @State private var showFilterSheet: Bool = false
    @State private var selectedTransaction: Transaction?
    @State private var showAccountsSheet = false
    @State private var pendingDeleteClosure: (() -> Void)?
    @State private var pendingDeleteTransactionId: PersistentIdentifier? = nil

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

    private var userLoans: [Loan] {
        guard let uid = currentUserId() else { return [] }
        return allLoans.filter { $0.userId == uid }
    }

    private var hasNoAccounts: Bool { userAccounts.isEmpty }

    private var dailyTransactions: [Transaction] {
        userTransactions
            .filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.date > $1.date }
    }

    private var periodTransactions: [Transaction] {
        userTransactions.filter { filter.matches($0, loans: userLoans) }
    }

    private var shownTransactions: [Transaction] {
        let base: [Transaction]
        switch viewMode {
        case .day:    base = dailyTransactions
        case .all:    base = userTransactions
        case .period: base = periodTransactions
        }
        return base.sorted {
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

    private var shownIncomeByCurrency: [(code: String, amount: Decimal)] {
        var dict: [String: Decimal] = [:]
        for t in shownTransactions where t.type == .income {
            dict[t.toAccount?.currency ?? "RUB", default: .zero] += t.amount
        }
        return dict.map { (code: $0.key, amount: $0.value) }.sorted { $0.amount > $1.amount }
    }

    private var shownExpenseByCurrency: [(code: String, amount: Decimal)] {
        var dict: [String: Decimal] = [:]
        for t in shownTransactions where t.type == .expense {
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

                    HStack(alignment: .center) {
                        Text("Кошелёк")
                            .font(.largeTitle.bold())
                        Spacer()
                        if viewMode == .day {
                            HStack(spacing: 4) {
                                Button {
                                    date = Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
                                } label: {
                                    Image(systemName: "chevron.left")
                                        .font(.caption.bold())
                                        .foregroundStyle(AppTheme.Colors.accent)
                                        .frame(width: 28, height: 28)
                                        .background(AppTheme.Colors.accent.opacity(0.1))
                                        .clipShape(Circle())
                                }
                                Button(action: { showDatePicker = true }) {
                                    Text(date.formatted(.dateTime
                                        .day(.defaultDigits)
                                        .month(.abbreviated)
                                        .locale(locale)
                                    ))
                                    .font(.subheadline.bold())
                                    .foregroundStyle(AppTheme.Colors.accent)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(AppTheme.Colors.accent.opacity(0.1))
                                    .clipShape(Capsule())
                                }
                                Button {
                                    date = Calendar.current.date(byAdding: .day, value: +1, to: date) ?? date
                                } label: {
                                    Image(systemName: "chevron.right")
                                        .font(.caption.bold())
                                        .foregroundStyle(AppTheme.Colors.accent)
                                        .frame(width: 28, height: 28)
                                        .background(AppTheme.Colors.accent.opacity(0.1))
                                        .clipShape(Circle())
                                }
                            }
                        } else {
                            Text(Date.now.formatted(.dateTime
                                .day(.defaultDigits)
                                .month(.abbreviated)
                                .year(.defaultDigits)
                                .locale(locale)
                            ))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)

                    if hasNoAccounts {
                        OnboardingCard()
                            .padding(.horizontal)
                            .padding(.top, 20)
                    } else {
                        BalanceCard(
                            balances: combinedBalances,
                            incomes: shownIncomeByCurrency,
                            expenses: shownExpenseByCurrency,
                            customCurrencies: userCurrencies,
                            onBalanceTap: { showAccountsSheet = true }
                        )
                        .padding(.horizontal)

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
                                        allLoans: userLoans,
                                        showDate: viewMode != .day,
                                        isSelected: selectedIds.contains(transaction.persistentModelID),
                                        isDeletePending: pendingDeleteTransactionId == transaction.persistentModelID,
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
                                            pendingDeleteTransactionId = transaction.persistentModelID
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
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
            .refreshable {
                let bm = SharedBudgetManager.shared
                guard bm.isParticipant || bm.shareURL != nil else { return }
                // Запускаем синк и сразу возвращаем управление — синк идёт в фоне.
                // Это убирает смещение тапов, которое было когда spinner держался 20-30 сек.
                autoSync.syncNow()
            }
            .overlay(alignment: .top) {
                if autoSync.isSyncing {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.75)
                        Text("Синхронизация…")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: autoSync.isSyncing)
            .background(AppTheme.Colors.pageBackground)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .padding(.top, 8)
        }
        .background(AppTheme.Colors.pageBackground.ignoresSafeArea())
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
            }
            Button("Отмена", role: .cancel) {
                pendingDeleteClosure = nil
                pendingDeleteTransactionId = nil
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
        .onChange(of: selectedIds) { _, newIds in
            selectionModel.selectedCount = newIds.count
            selectionModel.countLabel = selectionCountLabel
            selectionModel.onCancel = {
                withAnimation(.spring(duration: 0.3)) { selectedIds.removeAll() }
            }
            selectionModel.onBatchDelete = {
                showBatchDeleteAlert = true
            }
        }
        .onDisappear {
            selectionModel.selectedCount = 0
        }
        .onChange(of: viewMode) { _, _ in
            date = Date()
            selectedIds.removeAll()
        }
        // Очищаем прямые ссылки на транзакции, которые синк удалил из стора.
        // Без этого вьюха обращается к .priority zombie-объекта и крашится.
        .onChange(of: allTransactions) { _, newTransactions in
            let live = Set(newTransactions.map { $0.persistentModelID })
            if let sel = selectedTransaction, !live.contains(sel.persistentModelID) {
                selectedTransaction = nil
            }
            if !selectedIds.isEmpty {
                selectedIds = selectedIds.filter { live.contains($0) }
            }
            if let pendingId = pendingDeleteTransactionId, !live.contains(pendingId) {
                pendingDeleteTransactionId = nil
            }
        }
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

