//
//  CategoryDonutSection.swift
//  BalancePlaning
//

import SwiftUI
import Charts

// MARK: - Секция донат-чарта по категориям

struct CategoryDonutSection: View {
    let expenseGroups: [CategoryExpenseGroup]
    let incomeGroups: [CategoryExpenseGroup]
    let customCurrencies: [Currency]
    let currencyCode: String

    @State private var selectedSegment: ChartSegment = .expense

    enum ChartSegment: String, CaseIterable {
        case expense = "Расходы"
        case income  = "Доходы"
    }

    private let fallbackColors: [Color] = [
        Color(hex: "4361EE"), Color(hex: "F72585"), Color(hex: "4CC9F0"),
        Color(hex: "57CC99"), Color(hex: "F9C74F"), Color(hex: "FF8C42")
    ]

    private var activeGroups: [CategoryExpenseGroup] {
        selectedSegment == .expense ? expenseGroups : incomeGroups
    }

    private var totalAmount: Double {
        activeGroups.reduce(0) { $0 + $1.total }
    }

    private var currencySymbol: String {
        CurrencyInfo.symbol(for: currencyCode, custom: customCurrencies)
    }

    private func color(for index: Int, group: CategoryExpenseGroup) -> Color {
        group.rootColor ?? fallbackColors[index % fallbackColors.count]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("По категориям")
                    .font(.headline)
                Spacer()
                Picker("Тип", selection: $selectedSegment) {
                    ForEach(ChartSegment.allCases, id: \.self) { seg in
                        Text(seg.rawValue).tag(seg)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            if activeGroups.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "chart.pie")
                        .font(.system(size: 40))
                        .foregroundStyle(.quaternary)
                    Text("Нет операций за этот месяц")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .padding(.bottom, 8)
            } else {
                HStack(alignment: .top, spacing: 16) {
                    // Донат-чарт
                    ZStack {
                        Chart(Array(activeGroups.enumerated()), id: \.element.rootName) { index, group in
                            SectorMark(
                                angle: .value("Сумма", group.total),
                                innerRadius: .ratio(0.55),
                                angularInset: 2
                            )
                            .cornerRadius(4)
                            .foregroundStyle(color(for: index, group: group))
                        }
                        .frame(width: 130, height: 130)

                        VStack(spacing: 2) {
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text(totalAmount, format: .number.precision(.fractionLength(0...0)))
                                    .font(.system(size: 15, weight: .bold))
                                    .minimumScaleFactor(0.6)
                                    .lineLimit(1)
                                Text(currencySymbol)
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(width: 80)
                    }

                    // Список категорий
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(activeGroups.prefix(6).enumerated()), id: \.element.rootName) { index, group in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(color(for: index, group: group))
                                    .frame(width: 8, height: 8)
                                Text(group.rootName)
                                    .font(.caption)
                                    .lineLimit(1)
                                Spacer(minLength: 4)
                                VStack(alignment: .trailing, spacing: 1) {
                                    let pct = totalAmount > 0 ? group.total / totalAmount * 100 : 0
                                    Text("\(Int(pct))%")
                                        .font(.caption.bold())
                                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                                        Text(group.total, format: .number.precision(.fractionLength(0...0)))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        Text(currencySymbol)
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }
}
