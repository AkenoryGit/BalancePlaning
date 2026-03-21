//
//  SummaryPill.swift
//  BalancePlaning
//

import SwiftUI
import SwiftData

// MARK: - Плашка одной суммы

struct SummaryPill: View {
    let label: LocalizedStringKey
    let amount: Decimal
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(amount, format: .number.precision(.fractionLength(0...2)))
                    .font(.headline.bold())
                    .foregroundStyle(color)
                Text("₽")
                    .font(.subheadline.bold())
                    .foregroundStyle(color.opacity(0.8))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

// MARK: - Плашка с разбивкой по валютам

struct MultiCurrencyPill: View {
    let label: LocalizedStringKey
    let entries: [(code: String, amount: Decimal)]
    let color: Color
    let customCurrencies: [Currency]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            if entries.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("0")
                        .font(.title3.bold())
                        .foregroundStyle(color)
                    Text("₽")
                        .font(.headline.bold())
                        .foregroundStyle(color.opacity(0.8))
                }
            } else {
                ForEach(entries, id: \.code) { entry in
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(entry.amount, format: .number.precision(.fractionLength(0...2)))
                            .font(.title3.bold())
                            .foregroundStyle(color)
                        Text(CurrencyInfo.symbol(for: entry.code, custom: customCurrencies))
                            .font(.headline.bold())
                            .foregroundStyle(color.opacity(0.8))
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}
