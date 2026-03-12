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

    private var userTransactions: [Transaction] {
        guard let userId = currentUserId() else { return [] }
        return allTransactions.filter { $0.userId == userId }
    }

    private var monthlyTransactions: [Transaction] {
        userTransactions.filter {
            Calendar.current.isDate($0.date, equalTo: selectedMonth, toGranularity: .month)
        }
    }

    private var monthlyIncome: Decimal {
        monthlyTransactions.filter { $0.type == .income }.reduce(.zero) { $0 + $1.amount }
    }

    private var monthlyExpense: Decimal {
        monthlyTransactions.filter { $0.type == .expense }.reduce(.zero) { $0 + $1.amount }
    }

    private var balance: Decimal { monthlyIncome - monthlyExpense }

    /// Топ-5 категорий расходов
    private var expenseByCategory: [(name: String, amount: Double)] {
        var dict: [String: Decimal] = [:]
        for t in monthlyTransactions where t.type == .expense {
            let cat = t.toCategory?.name ?? "Другое"
            dict[cat, default: .zero] += t.amount
        }
        return dict
            .map { (name: $0.key, amount: Double(truncating: NSDecimalNumber(decimal: $0.value))) }
            .sorted { $0.amount > $1.amount }
            .prefix(5)
            .map { $0 }
    }

    /// Данные по дням для бар-чарта
    private var dailyChartData: [DayAmount] {
        var incomeByDay: [Int: Double] = [:]
        var expenseByDay: [Int: Double] = [:]
        let cal = Calendar.current
        for t in monthlyTransactions {
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
                result.append(DayAmount(date: date, amount: amount, kind: "Доходы"))
            }
        }
        for (day, amount) in expenseByDay {
            var dc = monthComponents; dc.day = day
            if let date = cal.date(from: dc) {
                result.append(DayAmount(date: date, amount: amount, kind: "Расходы"))
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
                    VStack(spacing: 4) {
                        Text("Баланс за месяц")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(balance >= 0 ? "+" : "")
                                .font(.title.bold())
                                .foregroundStyle(balance >= 0 ? AppTheme.Colors.income : AppTheme.Colors.expense)
                            Text(balance, format: .number.precision(.fractionLength(0...2)))
                                .font(.title.bold())
                                .foregroundStyle(balance >= 0 ? AppTheme.Colors.income : AppTheme.Colors.expense)
                            Text("₽")
                                .font(.title3.bold())
                                .foregroundStyle(balance >= 0 ? AppTheme.Colors.income : AppTheme.Colors.expense)
                        }
                    }
                    .padding(.vertical, 8)

                    // Доходы / Расходы
                    HStack(spacing: 12) {
                        SummaryPill(label: "Доходы", amount: monthlyIncome, color: AppTheme.Colors.income)
                        SummaryPill(label: "Расходы", amount: monthlyExpense, color: AppTheme.Colors.expense)
                    }
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
                                "Доходы":  AppTheme.Colors.income,
                                "Расходы": AppTheme.Colors.expense
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
                    if !expenseByCategory.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Топ расходов")
                                .font(.headline)
                                .padding(.horizontal, 16)
                                .padding(.top, 16)
                                .padding(.bottom, 8)

                            let maxAmount = expenseByCategory.first?.amount ?? 1

                            ForEach(Array(expenseByCategory.enumerated()), id: \.element.name) { index, item in
                                VStack(spacing: 0) {
                                    HStack(spacing: 12) {
                                        // Номер
                                        Text("\(index + 1)")
                                            .font(.caption.bold())
                                            .foregroundStyle(.secondary)
                                            .frame(width: 18)

                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Text(item.name)
                                                    .font(.subheadline)
                                                Spacer()
                                                HStack(alignment: .firstTextBaseline, spacing: 2) {
                                                    Text(item.amount, format: .number.precision(.fractionLength(0...2)))
                                                        .font(.subheadline.bold())
                                                    Text("₽")
                                                        .font(.caption.bold())
                                                        .foregroundStyle(.secondary)
                                                }
                                            }
                                            // Прогресс-бар
                                            GeometryReader { geo in
                                                ZStack(alignment: .leading) {
                                                    RoundedRectangle(cornerRadius: 3)
                                                        .fill(AppTheme.Colors.expense.opacity(0.12))
                                                        .frame(height: 6)
                                                    RoundedRectangle(cornerRadius: 3)
                                                        .fill(AppTheme.Colors.expense)
                                                        .frame(width: geo.size.width * CGFloat(item.amount / maxAmount), height: 6)
                                                }
                                            }
                                            .frame(height: 6)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)

                                    if index < expenseByCategory.count - 1 {
                                        Divider().padding(.leading, 46)
                                    }
                                }
                            }
                            .padding(.bottom, 8)
                        }
                        .cardStyle()
                        .padding(.horizontal)
                    } else {
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
        }
    }
}

// MARK: - Модель для чарта

struct DayAmount: Identifiable {
    let id = UUID()
    let date: Date
    let amount: Double
    let kind: String
}

// MARK: - Выбор месяца

struct MonthSelector: View {
    @Binding var selectedMonth: Date

    var body: some View {
        HStack {
            Button {
                selectedMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
            } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline.bold())
                    .frame(width: 36, height: 36)
                    .background(Color(.systemBackground))
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
            }

            Spacer()

            Text(selectedMonth.formatted(.dateTime
                .locale(Locale(identifier: "ru_RU"))
                .month(.wide)
                .year(.defaultDigits)
            ))
            .font(.headline)

            Spacer()

            Button {
                selectedMonth = Calendar.current.date(byAdding: .month, value: +1, to: selectedMonth) ?? selectedMonth
            } label: {
                Image(systemName: "chevron.right")
                    .font(.subheadline.bold())
                    .frame(width: 36, height: 36)
                    .background(Color(.systemBackground))
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
            }
        }
        .padding(.vertical, 4)
    }
}
