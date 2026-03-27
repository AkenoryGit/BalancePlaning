//
//  AnalyticsView.swift
//  BalancePlaning
//

import SwiftUI
import SwiftData
import Charts

// MARK: - Экран аналитики

struct AnalyticsView: View {
    @Environment(\.modelContext) var context
    @State private var selectedMonth: Date = {
        let cal = Calendar.current
        return cal.date(from: cal.dateComponents([.year, .month], from: Date()))!
    }()

    @Query private var allTransactions: [Transaction]
    @Query private var allCategories: [Category]
    @Query private var allCurrencies: [Currency]
    @Query private var allLoans: [Loan]
    @Query private var allLoanPayments: [LoanPayment]

    @EnvironmentObject private var autoSync: CloudKitAutoSyncManager
    @State private var includeLoanPayments: Bool = true

    private var accountService: AccountService { AccountService(context: context) }

    private var incomeChartLabel: String {
        AppSettings.shared.bundle.localizedString(forKey: "Доходы", value: "Доходы", table: nil)
    }
    private var expenseChartLabel: String {
        AppSettings.shared.bundle.localizedString(forKey: "Расходы", value: "Расходы", table: nil)
    }

    // MARK: - Computed: базовые данные

    private var userTransactions: [Transaction] {
        guard let userId = currentUserId() else { return [] }
        return allTransactions.filter { $0.userId == userId && $0.type != .correction }
    }

    private var futureTransactions: [Transaction] {
        userTransactions.filter { $0.date > Date() }
    }

    private var currentBalanceByCurrency: [(code: String, amount: Decimal)] {
        accountService.totalBalancePerCurrency(at: Date())
    }

    private var monthlyTransactions: [Transaction] {
        userTransactions.filter {
            Calendar.current.isDate($0.date, equalTo: selectedMonth, toGranularity: .month)
        }
    }

    private var filteredMonthlyTransactions: [Transaction] {
        monthlyTransactions.filter { t in
            if t.loanId != nil { return includeLoanPayments }
            return true
        }
    }

    private func expenseCurrency(for t: Transaction) -> String {
        if let account = t.fromAccount { return account.currency }
        if let loanId = t.loanId {
            return allLoans.first { $0.id == loanId }?.currency ?? "RUB"
        }
        return "RUB"
    }

    private var monthlyIncomeByCurrency: [(code: String, amount: Decimal)] {
        var dict: [String: Decimal] = [:]
        for t in filteredMonthlyTransactions where t.type == .income {
            let code = t.toAccount?.currency ?? "RUB"
            dict[code, default: .zero] += t.amount
        }
        return dict.map { (code: $0.key, amount: $0.value) }
                   .sorted { $0.amount > $1.amount }
    }

    private var monthlyExpenseByCurrency: [(code: String, amount: Decimal)] {
        var dict: [String: Decimal] = [:]
        for t in filteredMonthlyTransactions where t.type == .expense {
            let code = expenseCurrency(for: t)
            dict[code, default: .zero] += t.amount
        }
        return dict.map { (code: $0.key, amount: $0.value) }
                   .sorted { $0.amount > $1.amount }
    }

    private var monthlyBalanceByCurrency: [(code: String, amount: Decimal)] {
        var dict: [String: Decimal] = [:]
        for entry in monthlyIncomeByCurrency  { dict[entry.code, default: .zero] += entry.amount }
        for entry in monthlyExpenseByCurrency { dict[entry.code, default: .zero] -= entry.amount }
        return dict.map { (code: $0.key, amount: $0.value) }
                   .sorted { abs($0.amount) > abs($1.amount) }
    }

    private var expenseByCategoryGroup: [CategoryExpenseGroup] {
        var amountById: [UUID: Decimal] = [:]
        var loanPaymentsTotal: Decimal = .zero

        for t in filteredMonthlyTransactions where t.type == .expense {
            if t.loanId != nil {
                loanPaymentsTotal += t.amount
                continue
            }
            guard let cat = t.toCategory else { continue }
            amountById[cat.id, default: .zero] += t.amount
        }

        var rootTotals: [UUID: Decimal] = [:]
        var childrenMap: [UUID: [UUID: Decimal]] = [:]

        for (catId, amount) in amountById {
            guard let cat = allCategories.first(where: { $0.id == catId }) else { continue }
            let rootId = cat.parentId ?? cat.id
            rootTotals[rootId, default: .zero] += amount
            if cat.parentId != nil {
                childrenMap[rootId, default: [:]][catId, default: .zero] += amount
            }
        }

        let toDouble: (Decimal) -> Double = { Double(truncating: NSDecimalNumber(decimal: $0)) }

        var groups = rootTotals
            .compactMap { rootId, total -> CategoryExpenseGroup? in
                guard let root = allCategories.first(where: { $0.id == rootId }) else { return nil }
                let subs = (childrenMap[rootId] ?? [:])
                    .compactMap { childId, amt -> (name: String, amount: Double)? in
                        guard let child = allCategories.first(where: { $0.id == childId }) else { return nil }
                        return (name: child.name, amount: toDouble(amt))
                    }
                    .sorted { $0.amount > $1.amount }
                return CategoryExpenseGroup(
                    rootName: root.name,
                    rootColor: CategoryColors.resolve(root.color),
                    total: toDouble(total),
                    children: subs
                )
            }
            .sorted { $0.total > $1.total }
            .prefix(5)
            .map { $0 }

        if loanPaymentsTotal > 0 {
            groups.append(CategoryExpenseGroup(
                rootName: "Платежи по кредитам",
                rootColor: Color(hex: "E74C3C"),
                total: toDouble(loanPaymentsTotal),
                children: []
            ))
        }
        return groups
    }

    private var incomeByCategoryGroup: [CategoryExpenseGroup] {
        var amountById: [UUID: Decimal] = [:]
        for t in filteredMonthlyTransactions where t.type == .income {
            guard let cat = t.fromCategory else { continue }
            amountById[cat.id, default: .zero] += t.amount
        }

        var rootTotals: [UUID: Decimal] = [:]
        var childrenMap: [UUID: [UUID: Decimal]] = [:]

        for (catId, amount) in amountById {
            guard let cat = allCategories.first(where: { $0.id == catId }) else { continue }
            let rootId = cat.parentId ?? cat.id
            rootTotals[rootId, default: .zero] += amount
            if cat.parentId != nil {
                childrenMap[rootId, default: [:]][catId, default: .zero] += amount
            }
        }

        let toDouble: (Decimal) -> Double = { Double(truncating: NSDecimalNumber(decimal: $0)) }

        return rootTotals
            .compactMap { rootId, total -> CategoryExpenseGroup? in
                guard let root = allCategories.first(where: { $0.id == rootId }) else { return nil }
                let subs = (childrenMap[rootId] ?? [:])
                    .compactMap { childId, amt -> (name: String, amount: Double)? in
                        guard let child = allCategories.first(where: { $0.id == childId }) else { return nil }
                        return (name: child.name, amount: toDouble(amt))
                    }
                    .sorted { $0.amount > $1.amount }
                return CategoryExpenseGroup(
                    rootName: root.name,
                    rootColor: CategoryColors.resolve(root.color),
                    total: toDouble(total),
                    children: subs
                )
            }
            .sorted { $0.total > $1.total }
            .prefix(5)
            .map { $0 }
    }

    private var dailyChartData: [DayAmount] {
        var incomeByDay: [Int: Double] = [:]
        var expenseByDay: [Int: Double] = [:]
        let cal = Calendar.current
        for t in filteredMonthlyTransactions {
            let day = cal.component(.day, from: t.date)
            let amount = Double(truncating: NSDecimalNumber(decimal: t.amount))
            if t.type == .income  { incomeByDay[day, default: 0]  += amount }
            if t.type == .expense { expenseByDay[day, default: 0] += amount }
        }
        let monthComponents = cal.dateComponents([.year, .month], from: selectedMonth)
        var result: [DayAmount] = []
        for (day, amount) in incomeByDay {
            var dc = monthComponents; dc.day = day
            if let date = cal.date(from: dc) {
                result.append(DayAmount(date: date, amount: amount, kind: incomeChartLabel))
            }
        }
        for (day, amount) in expenseByDay {
            var dc = monthComponents; dc.day = day
            if let date = cal.date(from: dc) {
                result.append(DayAmount(date: date, amount: amount, kind: expenseChartLabel))
            }
        }
        return result.sorted { $0.date < $1.date }
    }

    // MARK: - Computed: новые данные

    /// Основная валюта аналитики
    private var currencyCodeForAnalytics: String {
        monthlyExpenseByCurrency.first?.code
            ?? monthlyIncomeByCurrency.first?.code
            ?? "RUB"
    }

    /// Доходы за месяц в основной валюте (Double для расчётов)
    private var monthlyIncomeDouble: Double {
        let code = currencyCodeForAnalytics
        guard let entry = monthlyIncomeByCurrency.first(where: { $0.code == code }) else {
            return monthlyIncomeByCurrency.first.map {
                Double(truncating: NSDecimalNumber(decimal: $0.amount))
            } ?? 0
        }
        return Double(truncating: NSDecimalNumber(decimal: entry.amount))
    }

    /// Данные за последние 6 месяцев для сравнительного чарта
    private var last6MonthsData: [MonthSummary] {
        let cal = Calendar.current
        let toDouble: (Decimal) -> Double = { Double(truncating: NSDecimalNumber(decimal: $0)) }

        return (0..<6).compactMap { offset -> MonthSummary? in
            guard let month = cal.date(byAdding: .month, value: -(5 - offset), to: selectedMonth) else { return nil }

            var incomeTotal: Decimal = .zero
            var expenseTotal: Decimal = .zero

            for t in userTransactions {
                guard cal.isDate(t.date, equalTo: month, toGranularity: .month) else { continue }
                if !includeLoanPayments && t.loanId != nil { continue }
                if t.type == .income  { incomeTotal  += t.amount }
                if t.type == .expense { expenseTotal += t.amount }
            }

            return MonthSummary(
                month: month,
                income: toDouble(incomeTotal),
                expense: toDouble(expenseTotal)
            )
        }
    }

    /// Топ-5 крупнейших операций за месяц
    private var topTransactions: [Transaction] {
        filteredMonthlyTransactions
            .filter { $0.type == .income || $0.type == .expense }
            .sorted { $0.amount > $1.amount }
            .prefix(5)
            .map { $0 }
    }

    /// Активные кредиты текущего пользователя
    private var activeLoans: [Loan] {
        guard let userId = currentUserId() else { return [] }
        return allLoans.filter { $0.userId == userId && !$0.isArchived }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    // Заголовок + кнопка фильтра
                    HStack {
                        Text("Аналитика")
                            .font(.largeTitle.bold())
                        Spacer()
                        Menu {
                            Section("Показывать в аналитике") {
                                Button {
                                    includeLoanPayments.toggle()
                                } label: {
                                    Label(
                                        "Платежи по кредитам",
                                        systemImage: includeLoanPayments ? "checkmark" : ""
                                    )
                                }
                            }
                        } label: {
                            Image(systemName: includeLoanPayments
                                  ? "line.3.horizontal.decrease.circle.fill"
                                  : "line.3.horizontal.decrease.circle")
                                .foregroundStyle(includeLoanPayments ? AppTheme.Colors.accent : .secondary)
                                .font(.title3)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)

                    // Выбор месяца
                    MonthSelector(selectedMonth: $selectedMonth)
                        .padding(.horizontal)

                    // Сводка месяца: Доходы / Расходы / Поток
                    monthlySummaryCards

                    // Донат-чарт по категориям
                    CategoryDonutSection(
                        expenseGroups: expenseByCategoryGroup,
                        incomeGroups: incomeByCategoryGroup,
                        customCurrencies: allCurrencies,
                        currencyCode: currencyCodeForAnalytics
                    )
                    .cardStyle()
                    .padding(.horizontal)

                    // Сравнение за 6 месяцев
                    MonthlyComparisonSection(
                        data: last6MonthsData,
                        selectedMonth: selectedMonth,
                        customCurrencies: allCurrencies,
                        currencyCode: currencyCodeForAnalytics
                    )
                    .cardStyle()
                    .padding(.horizontal)

                    // Бар-чарт по дням
                    dailyChartCard

                    // Топ-5 крупнейших операций
                    TopTransactionsSection(
                        transactions: topTransactions,
                        allCategories: allCategories,
                        customCurrencies: allCurrencies
                    )
                    .cardStyle()
                    .padding(.horizontal)

                    // Прогноз баланса
                    ForecastSection(
                        startBalances: currentBalanceByCurrency,
                        futureTransactions: futureTransactions,
                        customCurrencies: allCurrencies
                    )
                    .cardStyle()
                    .padding(.horizontal)

                    // Кредитная нагрузка
                    if !activeLoans.isEmpty {
                        LoanAnalyticsSection(
                            activeLoans: activeLoans,
                            allPayments: allLoanPayments,
                            monthlyIncome: monthlyIncomeDouble,
                            customCurrencies: allCurrencies
                        )
                        .cardStyle()
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
            .refreshable {
                let bm = SharedBudgetManager.shared
                guard bm.isParticipant || bm.shareURL != nil else { return }
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
    }

    // MARK: - Сводка месяца

    @ViewBuilder
    private var monthlySummaryCards: some View {
        let incomeEntry  = monthlyIncomeByCurrency.first
        let expenseEntry = monthlyExpenseByCurrency.first
        let code         = currencyCodeForAnalytics
        let symbol       = CurrencyInfo.symbol(for: code, custom: allCurrencies)

        let incomeAmount  = incomeEntry.map  { Double(truncating: NSDecimalNumber(decimal: $0.amount)) } ?? 0
        let expenseAmount = expenseEntry.map { Double(truncating: NSDecimalNumber(decimal: $0.amount)) } ?? 0
        let flowAmount    = incomeAmount - expenseAmount
        let flowColor: Color = flowAmount >= 0 ? AppTheme.Colors.income : AppTheme.Colors.expense

        HStack(spacing: 10) {
            summaryCard(
                label: "Доходы",
                amount: incomeAmount,
                symbol: symbol,
                color: AppTheme.Colors.income
            )
            summaryCard(
                label: "Расходы",
                amount: expenseAmount,
                symbol: symbol,
                color: AppTheme.Colors.expense
            )
            summaryCard(
                label: "Поток",
                amount: flowAmount,
                symbol: symbol,
                color: flowColor,
                showSign: true
            )
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func summaryCard(
        label: String,
        amount: Double,
        symbol: String,
        color: Color,
        showSign: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                if showSign && amount != 0 {
                    Text(amount > 0 ? "+" : "")
                        .font(.callout.bold())
                        .foregroundStyle(color)
                }
                Text(abs(amount), format: .number.precision(.fractionLength(0...2)))
                    .font(.callout.bold())
                    .foregroundStyle(color)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(symbol)
                    .font(.caption.bold())
                    .foregroundStyle(color.opacity(0.8))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // MARK: - Бар-чарт по дням

    @ViewBuilder
    private var dailyChartCard: some View {
        if !dailyChartData.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("По дням")
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 0)

                Chart(dailyChartData) { item in
                    BarMark(
                        x: .value("День", item.date, unit: .day),
                        y: .value("Сумма", item.amount)
                    )
                    .foregroundStyle(by: .value("Тип", item.kind))
                    .cornerRadius(4)
                }
                .chartForegroundStyleScale([
                    incomeChartLabel:  AppTheme.Colors.income,
                    expenseChartLabel: AppTheme.Colors.expense
                ])
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 6)) {
                        AxisValueLabel(format: .dateTime.day())
                        AxisGridLine()
                    }
                }
                .chartLegend(position: .top, alignment: .leading)
                .frame(height: 180)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .cardStyle()
            .padding(.horizontal)
        }
    }
}
