//
//  MonthlyComparisonSection.swift
//  BalancePlaning
//

import SwiftUI
import Charts

// MARK: - Секция сравнения месяцев

struct MonthlyComparisonSection: View {
    let data: [MonthSummary]
    let selectedMonth: Date
    let customCurrencies: [Currency]
    let currencyCode: String

    private var currencySymbol: String {
        CurrencyInfo.symbol(for: currencyCode, custom: customCurrencies)
    }

    private var selectedSummary: MonthSummary? {
        data.first {
            Calendar.current.isDate($0.month, equalTo: selectedMonth, toGranularity: .month)
        }
    }

    private var barData: [MonthBar] {
        var result: [MonthBar] = []
        for summary in data {
            result.append(MonthBar(month: summary.month, amount: summary.income,  kind: "Доходы"))
            result.append(MonthBar(month: summary.month, amount: summary.expense, kind: "Расходы"))
        }
        return result
    }

    private func isSelected(_ month: Date) -> Bool {
        Calendar.current.isDate(month, equalTo: selectedMonth, toGranularity: .month)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Сравнение месяцев")
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            Chart(barData) { item in
                BarMark(
                    x: .value("Месяц", item.month, unit: .month),
                    y: .value("Сумма", item.amount)
                )
                .foregroundStyle(by: .value("Тип", item.kind))
                .opacity(isSelected(item.month) ? 1.0 : 0.6)
                .position(by: .value("Тип", item.kind))
                .cornerRadius(3)
            }
            .chartForegroundStyleScale([
                "Доходы":  AppTheme.Colors.income,
                "Расходы": AppTheme.Colors.expense
            ])
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) {
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
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
            .chartLegend(position: .top, alignment: .leading)
            .frame(height: 160)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            if let summary = selectedSummary {
                Divider()
                    .padding(.horizontal, 16)

                VStack(spacing: 6) {
                    HStack {
                        Text("Доходы")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(summary.income, format: .number.precision(.fractionLength(0...2)))
                                .font(.subheadline.bold())
                                .foregroundStyle(AppTheme.Colors.income)
                            Text(currencySymbol)
                                .font(.caption.bold())
                                .foregroundStyle(AppTheme.Colors.income.opacity(0.8))
                        }
                    }
                    HStack {
                        Text("Расходы")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(summary.expense, format: .number.precision(.fractionLength(0...2)))
                                .font(.subheadline.bold())
                                .foregroundStyle(AppTheme.Colors.expense)
                            Text(currencySymbol)
                                .font(.caption.bold())
                                .foregroundStyle(AppTheme.Colors.expense.opacity(0.8))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
    }

    private func formatAxisValue(_ v: Double) -> String {
        let a = abs(v)
        if a >= 1_000_000 { return "\(Int(v / 1_000_000))М" }
        if a >= 1_000     { return "\(Int(v / 1_000))к" }
        return "\(Int(v))"
    }
}
