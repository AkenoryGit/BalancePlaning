//
//  ForecastSection.swift
//  BalancePlaning
//

import SwiftUI
import Charts

// MARK: - Секция прогноза баланса

struct ForecastSection: View {
    /// Текущий баланс по валютам (уже посчитан в AnalyticsView через AccountService)
    let startBalances: [(code: String, amount: Decimal)]
    /// Все будущие транзакции пользователя (date > today)
    let futureTransactions: [Transaction]
    let customCurrencies: [Currency]

    @State private var selectedCurrency: String = ""

    // Валюты, задействованные в стартовых балансах или будущих транзакциях
    private var availableCurrencies: [String] {
        var codes = Set(startBalances.map { $0.code })
        for t in futureTransactions {
            if let c = t.toAccount?.currency   { codes.insert(c) }
            if let c = t.fromAccount?.currency { codes.insert(c) }
        }
        return codes.sorted { a, b in
            let ia = CurrencyInfo.predefined.firstIndex { $0.code == a } ?? 99
            let ib = CurrencyInfo.predefined.firstIndex { $0.code == b } ?? 99
            return ia == ib ? a < b : ia < ib
        }
    }

    private var currentBalance: Decimal {
        startBalances.first { $0.code == selectedCurrency }?.amount ?? .zero
    }

    private var points: [ForecastPoint] {
        guard !selectedCurrency.isEmpty else { return [] }
        return buildForecastPoints(currency: selectedCurrency, startBalance: currentBalance)
    }

    private var firstNegativeDate: Date? {
        points.first { $0.balance < 0 }?.date
    }

    private var hasNegative: Bool { firstNegativeDate != nil }

    private var lineColor: Color {
        hasNegative ? AppTheme.Colors.expense : AppTheme.Colors.income
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Заголовок
            VStack(alignment: .leading, spacing: 2) {
                Text("Прогноз баланса")
                    .font(.headline)
                Text("На основе запланированных операций · 6 месяцев")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Выбор валюты
            if availableCurrencies.count > 1 {
                Picker("Валюта", selection: $selectedCurrency) {
                    ForEach(availableCurrencies, id: \.self) { code in
                        Text(CurrencyInfo.symbol(for: code, custom: customCurrencies)).tag(code)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }

            if points.count < 2 {
                // Нет будущих операций
                VStack(spacing: 10) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 40))
                        .foregroundStyle(.quaternary)
                    Text("Нет запланированных операций")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Создайте повторяющиеся операции,\nчтобы увидеть прогноз")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .padding(.bottom, 8)
            } else {

                // Предупреждение об уходе в минус
                if let negDate = firstNegativeDate {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("Баланс уйдёт в минус ~\(negDate.formatted(.dateTime.locale(Locale(identifier: "ru_RU")).day().month(.wide).year()))")
                            .font(.caption.bold())
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.Colors.expense)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }

                // График
                let hasNeg = hasNegative
                let lColor = lineColor
                Chart {
                    ForEach(points) { point in
                        AreaMark(
                            x: .value("Дата", point.date),
                            y: .value("Баланс", toDouble(point.balance))
                        )
                        .foregroundStyle(lColor.opacity(0.1))

                        LineMark(
                            x: .value("Дата", point.date),
                            y: .value("Баланс", toDouble(point.balance))
                        )
                        .foregroundStyle(lColor)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .interpolationMethod(.catmullRom)
                    }
                    if hasNeg {
                        RuleMark(y: .value("Ноль", 0))
                            .foregroundStyle(AppTheme.Colors.expense.opacity(0.6))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) {
                        AxisValueLabel(format: .dateTime
                            .locale(Locale(identifier: "ru_RU"))
                            .month(.abbreviated))
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4))
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4))
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(formatAxisValue(v))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 160)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)

                Divider()

                // Milestone-строка: +1 мес / +3 мес / +6 мес
                HStack(spacing: 0) {
                    ForEach([1, 3, 6], id: \.self) { months in
                        let projected = balanceAt(months: months)
                        let diff = projected - currentBalance
                        let symbol = CurrencyInfo.symbol(for: selectedCurrency, custom: customCurrencies)

                        VStack(spacing: 4) {
                            Text(milestoneLabel(months))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text(projected, format: .number.precision(.fractionLength(0...0)))
                                    .font(.subheadline.bold())
                                    .foregroundStyle(projected >= 0 ? .primary : AppTheme.Colors.expense)
                                Text(symbol)
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 2) {
                                Image(systemName: diff >= 0 ? "arrow.up" : "arrow.down")
                                    .font(.caption2.bold())
                                Text(abs(diff), format: .number.precision(.fractionLength(0...0)))
                                    .font(.caption2)
                            }
                            .foregroundStyle(diff >= 0 ? AppTheme.Colors.income : AppTheme.Colors.expense)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)

                        if months != 6 { Divider() }
                    }
                }
            }
        }
        .onAppear { initCurrency() }
        .onChange(of: availableCurrencies) { _, _ in initCurrency() }
    }

    // MARK: - Helpers

    private func initCurrency() {
        if selectedCurrency.isEmpty || !availableCurrencies.contains(selectedCurrency) {
            selectedCurrency = availableCurrencies.first ?? "RUB"
        }
    }

    private func milestoneLabel(_ months: Int) -> String {
        switch months {
        case 1: return "+1 мес"
        case 3: return "+3 мес"
        default: return "+6 мес"
        }
    }

    private func balanceAt(months: Int) -> Decimal {
        let target = Calendar.current.date(byAdding: .month, value: months,
                                           to: Calendar.current.startOfDay(for: Date()))!
        return points.last { $0.date <= target }?.balance ?? currentBalance
    }

    private func toDouble(_ d: Decimal) -> Double {
        Double(truncating: NSDecimalNumber(decimal: d))
    }

    private func formatAxisValue(_ v: Double) -> String {
        let a = abs(v)
        if a >= 1_000_000 { return "\(Int(v / 1_000_000))М" }
        if a >= 1_000     { return "\(Int(v / 1_000))к" }
        return "\(Int(v))"
    }

    // MARK: - Построение точек прогноза

    private func buildForecastPoints(currency: String, startBalance: Decimal) -> [ForecastPoint] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let endDate = cal.date(byAdding: .month, value: 6, to: today)!

        // Дневные изменения баланса
        var dailyNet: [Date: Decimal] = [:]
        for t in futureTransactions {
            let day = cal.startOfDay(for: t.date)
            guard day > today, day <= endDate else { continue }
            let net = netChange(t, currency: currency)
            if net != .zero { dailyNet[day, default: .zero] += net }
        }

        guard !dailyNet.isEmpty else {
            return [ForecastPoint(date: today, balance: startBalance)]
        }

        // Недельные точки
        var result: [ForecastPoint] = [ForecastPoint(date: today, balance: startBalance)]
        var balance = startBalance
        var weekStart = today

        while weekStart < endDate {
            let nextWeek = cal.date(byAdding: .day, value: 7, to: weekStart)!
            let weekEnd = nextWeek <= endDate ? nextWeek : endDate
            var d = cal.date(byAdding: .day, value: 1, to: weekStart)!
            while d <= weekEnd {
                balance += dailyNet[d] ?? .zero
                d = cal.date(byAdding: .day, value: 1, to: d)!
            }
            result.append(ForecastPoint(date: weekEnd, balance: balance))
            guard weekEnd < endDate else { break }
            weekStart = weekEnd
        }

        return result
    }

    private func netChange(_ t: Transaction, currency: String) -> Decimal {
        switch t.type {
        case .income:
            return t.toAccount?.currency == currency ? t.amount : .zero
        case .expense:
            return t.fromAccount?.currency == currency ? -t.amount : .zero
        case .transaction:
            var net = Decimal.zero
            if t.fromAccount?.currency == currency { net -= t.amount }
            if t.toAccount?.currency == currency   { net += t.toAmount ?? t.amount }
            return net
        case .correction:
            var net = Decimal.zero
            if let to   = t.toAccount,   to.currency   == currency { net += t.amount }
            if let from = t.fromAccount, from.currency == currency { net -= t.amount }
            return net
        }
    }
}

// MARK: - Точка прогноза

struct ForecastPoint: Identifiable {
    let id = UUID()
    let date: Date
    let balance: Decimal
}
