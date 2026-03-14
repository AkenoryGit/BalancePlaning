//
//  TransactionsView.swift
//  BalancePlaning
//

import SwiftUI
import SwiftData

// MARK: - Главный экран (Dashboard)

struct TransactionsView: View {
    @Environment(\.modelContext) var context
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

    @Query private var allTransactions: [Transaction]
    @Query private var allCurrencies: [Currency]
    @Query private var allCategories: [Category]
    @Query private var allGroups: [AccountGroup]
    @Query private var allAccounts: [Account]

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

    private var accountService: AccountService { AccountService(context: context) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    // Онбординг для нового пользователя
                    if hasNoAccounts {
                        OnboardingCard()
                            .padding(.horizontal)
                    }

                    // Карточка баланса
                    BalanceCard(
                        balances: accountService.totalBalancePerCurrency(at: date),
                        date: $date,
                        showNavigation: viewMode == .day,
                        customCurrencies: userCurrencies,
                        onDateTap: { showDatePicker = true },
                        onBalanceTap: { showAccountsSheet = true }
                    )
                    .padding(.horizontal)

                    // Итоги за день (только в режиме «за день»)
                    if viewMode == .day {
                        HStack(alignment: .top, spacing: 12) {
                            MultiCurrencyPill(label: "Доходы", entries: dailyIncomeByCurrency,
                                             color: AppTheme.Colors.income, customCurrencies: userCurrencies)
                            MultiCurrencyPill(label: "Расходы", entries: dailyExpenseByCurrency,
                                             color: AppTheme.Colors.expense, customCurrencies: userCurrencies)
                        }
                        .padding(.horizontal)
                    }

                    // Переключатель режима
                    Picker("", selection: $viewMode) {
                        ForEach(TransactionViewMode.allCases, id: \.self) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Строка фильтра (в режиме «За период»)
                    if viewMode == .period {
                        Button { showFilterSheet = true } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                    .foregroundStyle(AppTheme.Colors.accent)
                                VStack(alignment: .leading, spacing: 1) {
                                    HStack(spacing: 4) {
                                        Text(filter.startDate, format: .dateTime.day(.twoDigits).month(.twoDigits).year())
                                        Text("—")
                                        Text(filter.endDate, format: .dateTime.day(.twoDigits).month(.twoDigits).year())
                                    }
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.primary)
                                    if filter.activeFilterCount > 0 {
                                        Text("Ещё \(filter.activeFilterCount) фильтр\(filterSuffix(filter.activeFilterCount))")
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

                    // Список транзакций
                    if shownTransactions.isEmpty {
                        EmptyTransactionsPlaceholder(viewMode: viewMode)
                            .padding(.top, 40)
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(shownTransactions) { transaction in
                                TransactionCard(transaction: transaction,
                                                allCategories: userCategories,
                                                allGroups: userGroups,
                                                showDate: viewMode != .day)
                                    .padding(.horizontal)
                                    .onTapGesture { selectedTransaction = transaction }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            let service = TransactionService(context: context)
                                            pendingDeleteClosure = { service.deleteTransaction(transaction) }
                                            withAnimation(.default, completionCriteria: .logicallyComplete) {
                                                pendingDeleteId = transaction.persistentModelID
                                            } completion: {
                                                pendingDeleteClosure?()
                                                pendingDeleteClosure = nil
                                                pendingDeleteId = nil
                                            }
                                        } label: {
                                            Label("Удалить", systemImage: "trash")
                                        }
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
                if !hasNoAccounts {
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
                }
            }
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
        .onChange(of: viewMode) { _, _ in
            date = Date()
        }
    }

    private func filterSuffix(_ n: Int) -> String {
        if n == 1 { return "" }
        if n < 5  { return "а" }
        return "ов"
    }
}
