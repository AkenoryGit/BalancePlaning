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

    @State private var includeLoanPayments: Bool = true

    private var accountService: AccountService { AccountService(context: context) }

    private var incomeChartLabel: String {
        AppSettings.shared.bundle.localizedString(forKey: "Доходы", value: "Доходы", table: nil)
    }
    private var expenseChartLabel: String {
        AppSettings.shared.bundle.localizedString(forKey: "Расходы", value: "Расходы", table: nil)
    }

    private var userTransactions: [Transaction] {
        guard let userId = currentUserId() else { return [] }
        // Корректировки не участвуют в аналитике
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

    /// Транзакции за месяц с учётом фильтра
    private var filteredMonthlyTransactions: [Transaction] {
        monthlyTransactions.filter { t in
            if t.loanId != nil { return includeLoanPayments }
            return true
        }
    }

    /// Валюта для транзакции — для платежей без счёта берём из кредита
    private func expenseCurrency(for t: Transaction) -> String {
        if let account = t.fromAccount { return account.currency }
        if let loanId = t.loanId {
            return allLoans.first { $0.id == loanId }?.currency ?? "RUB"
        }
        return "RUB"
    }

    /// Доходы по валютам: код → сумма
    private var monthlyIncomeByCurrency: [(code: String, amount: Decimal)] {
        var dict: [String: Decimal] = [:]
        for t in filteredMonthlyTransactions where t.type == .income {
            let code = t.toAccount?.currency ?? "RUB"
            dict[code, default: .zero] += t.amount
        }
        return dict.map { (code: $0.key, amount: $0.value) }
                   .sorted { $0.amount > $1.amount }
    }

    /// Расходы по валютам: код → сумма
    private var monthlyExpenseByCurrency: [(code: String, amount: Decimal)] {
        var dict: [String: Decimal] = [:]
        for t in filteredMonthlyTransactions where t.type == .expense {
            let code = expenseCurrency(for: t)
            dict[code, default: .zero] += t.amount
        }
        return dict.map { (code: $0.key, amount: $0.value) }
                   .sorted { $0.amount > $1.amount }
    }

    /// Баланс по валютам (доход − расход)
    private var monthlyBalanceByCurrency: [(code: String, amount: Decimal)] {
        var dict: [String: Decimal] = [:]
        for entry in monthlyIncomeByCurrency  { dict[entry.code, default: .zero] += entry.amount }
        for entry in monthlyExpenseByCurrency { dict[entry.code, default: .zero] -= entry.amount }
        return dict.map { (code: $0.key, amount: $0.value) }
                   .sorted { abs($0.amount) > abs($1.amount) }
    }

    /// Топ расходов, сгруппированных по корневой категории
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

        // Резолвим корневую категорию и накапливаем
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

    /// Топ доходов, сгруппированных по корневой категории
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

    /// Данные по дням для бар-чарта
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    // Выбор месяца
                    MonthSelector(selectedMonth: $selectedMonth)
                        .padding(.horizontal)

                    // Баланс за месяц
                    VStack(spacing: 6) {
                        Text("Баланс за месяц")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if monthlyBalanceByCurrency.isEmpty {
                            Text("0 ₽")
                                .font(.title.bold())
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(monthlyBalanceByCurrency, id: \.code) { entry in
                                let color = entry.amount >= 0 ? AppTheme.Colors.income : AppTheme.Colors.expense
                                HStack(alignment: .firstTextBaseline, spacing: 3) {
                                    Text(entry.amount >= 0 ? "+" : "")
                                        .font(monthlyBalanceByCurrency.count == 1 ? .title.bold() : .title2.bold())
                                        .foregroundStyle(color)
                                    Text(entry.amount, format: .number.precision(.fractionLength(0...2)))
                                        .font(monthlyBalanceByCurrency.count == 1 ? .title.bold() : .title2.bold())
                                        .foregroundStyle(color)
                                    Text(CurrencyInfo.symbol(for: entry.code, custom: allCurrencies))
                                        .font(monthlyBalanceByCurrency.count == 1 ? .title3.bold() : .headline.bold())
                                        .foregroundStyle(color)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)

                    // Доходы / Расходы
                    HStack(alignment: .top, spacing: 12) {
                        MultiCurrencyPill(
                            label: "Доходы",
                            entries: monthlyIncomeByCurrency,
                            color: AppTheme.Colors.income,
                            customCurrencies: allCurrencies
                        )
                        MultiCurrencyPill(
                            label: "Расходы",
                            entries: monthlyExpenseByCurrency,
                            color: AppTheme.Colors.expense,
                            customCurrencies: allCurrencies
                        )
                    }
                    .padding(.horizontal)

                    // Прогноз баланса
                    ForecastSection(
                        startBalances: currentBalanceByCurrency,
                        futureTransactions: futureTransactions,
                        customCurrencies: allCurrencies
                    )
                    .cardStyle()
                    .padding(.horizontal)

                    // Бар-чарт по дням
                    if !dailyChartData.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("По дням")
                                .font(.headline)
                                .padding(.horizontal)

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
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                        }
                        .padding(.vertical, 12)
                        .cardStyle()
                        .padding(.horizontal)
                    }

                    // Топ расходов по категориям
                    if !expenseByCategoryGroup.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Топ расходов")
                                .font(.headline)
                                .padding(.horizontal, 16)
                                .padding(.top, 16)
                                .padding(.bottom, 8)

                            let maxAmount = expenseByCategoryGroup.first?.total ?? 1

                            ForEach(Array(expenseByCategoryGroup.enumerated()), id: \.element.rootName) { index, group in
                                VStack(spacing: 0) {
                                    // Строка корневой категории
                                    HStack(spacing: 12) {
                                        Text("\(index + 1)")
                                            .font(.caption.bold())
                                            .foregroundStyle(.secondary)
                                            .frame(width: 18)

                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Text(group.rootName)
                                                    .font(.subheadline.bold())
                                                Spacer()
                                                HStack(alignment: .firstTextBaseline, spacing: 2) {
                                                    Text(group.total, format: .number.precision(.fractionLength(0...2)))
                                                        .font(.subheadline.bold())
                                                    Text("₽")
                                                        .font(.caption.bold())
                                                        .foregroundStyle(.secondary)
                                                }
                                            }
                                            GeometryReader { geo in
                                                let barColor = group.rootColor ?? AppTheme.Colors.expense
                                                ZStack(alignment: .leading) {
                                                    RoundedRectangle(cornerRadius: 3)
                                                        .fill(barColor.opacity(0.12))
                                                        .frame(height: 6)
                                                    RoundedRectangle(cornerRadius: 3)
                                                        .fill(barColor)
                                                        .frame(width: geo.size.width * CGFloat(group.total / maxAmount), height: 6)
                                                }
                                            }
                                            .frame(height: 6)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.top, 12)
                                    .padding(.bottom, group.children.isEmpty ? 12 : 6)

                                    // Подкатегории
                                    if !group.children.isEmpty {
                                        ForEach(group.children, id: \.name) { child in
                                            HStack(spacing: 12) {
                                                // отступ под номер
                                                Color.clear.frame(width: 18)

                                                HStack {
                                                    Text(child.name)
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                    Spacer()
                                                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                                                        Text(child.amount, format: .number.precision(.fractionLength(0...2)))
                                                            .font(.caption.bold())
                                                            .foregroundStyle(.secondary)
                                                        Text("₽")
                                                            .font(.caption2.bold())
                                                            .foregroundStyle(.tertiary)
                                                    }
                                                }
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 4)
                                        }
                                        .padding(.bottom, 8)
                                    }

                                    if index < expenseByCategoryGroup.count - 1 {
                                        Divider().padding(.leading, 46)
                                    }
                                }
                            }
                            .padding(.bottom, 8)
                        }
                        .cardStyle()
                        .padding(.horizontal)
                    }

                    // Топ доходов по категориям
                    if !incomeByCategoryGroup.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Топ доходов")
                                .font(.headline)
                                .padding(.horizontal, 16)
                                .padding(.top, 16)
                                .padding(.bottom, 8)

                            let maxAmount = incomeByCategoryGroup.first?.total ?? 1

                            ForEach(Array(incomeByCategoryGroup.enumerated()), id: \.element.rootName) { index, group in
                                VStack(spacing: 0) {
                                    HStack(spacing: 12) {
                                        Text("\(index + 1)")
                                            .font(.caption.bold())
                                            .foregroundStyle(.secondary)
                                            .frame(width: 18)

                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Text(group.rootName)
                                                    .font(.subheadline.bold())
                                                Spacer()
                                                HStack(alignment: .firstTextBaseline, spacing: 2) {
                                                    Text(group.total, format: .number.precision(.fractionLength(0...2)))
                                                        .font(.subheadline.bold())
                                                    Text("₽")
                                                        .font(.caption.bold())
                                                        .foregroundStyle(.secondary)
                                                }
                                            }
                                            GeometryReader { geo in
                                                let barColor = group.rootColor ?? AppTheme.Colors.income
                                                ZStack(alignment: .leading) {
                                                    RoundedRectangle(cornerRadius: 3)
                                                        .fill(barColor.opacity(0.12))
                                                        .frame(height: 6)
                                                    RoundedRectangle(cornerRadius: 3)
                                                        .fill(barColor)
                                                        .frame(width: geo.size.width * CGFloat(group.total / maxAmount), height: 6)
                                                }
                                            }
                                            .frame(height: 6)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.top, 12)
                                    .padding(.bottom, group.children.isEmpty ? 12 : 6)

                                    if !group.children.isEmpty {
                                        ForEach(group.children, id: \.name) { child in
                                            HStack(spacing: 12) {
                                                Color.clear.frame(width: 18)
                                                HStack {
                                                    Text(child.name)
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                    Spacer()
                                                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                                                        Text(child.amount, format: .number.precision(.fractionLength(0...2)))
                                                            .font(.caption.bold())
                                                            .foregroundStyle(.secondary)
                                                        Text("₽")
                                                            .font(.caption2.bold())
                                                            .foregroundStyle(.tertiary)
                                                    }
                                                }
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 4)
                                        }
                                        .padding(.bottom, 8)
                                    }

                                    if index < incomeByCategoryGroup.count - 1 {
                                        Divider().padding(.leading, 46)
                                    }
                                }
                            }
                            .padding(.bottom, 8)
                        }
                        .cardStyle()
                        .padding(.horizontal)
                    }

                    if expenseByCategoryGroup.isEmpty && incomeByCategoryGroup.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "chart.pie")
                                .font(.system(size: 52))
                                .foregroundStyle(.quaternary)
                            Text("Нет данных за этот месяц")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text("Добавьте операции чтобы увидеть аналитику")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 40)
                        .padding(.horizontal, 40)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(AppTheme.Colors.pageBackground)
            .navigationTitle("Аналитика")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
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
                    }
                }
            }
        }
    }
}

