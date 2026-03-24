//
//  BalanceCard.swift
//  BalancePlaning
//

import SwiftUI
import SwiftData

// MARK: - Карточка баланса

struct BalanceCard: View {
    let balances: [(code: String, amount: Decimal)]
    let incomes: [(code: String, amount: Decimal)]
    let expenses: [(code: String, amount: Decimal)]
    let customCurrencies: [Currency]
    var onBalanceTap: (() -> Void)? = nil

    var body: some View {
        Button(action: { onBalanceTap?() }) {
            VStack(alignment: .leading, spacing: 16) {

                // Верхняя строка: метка слева, кошелёк справа
                HStack(alignment: .top) {
                    HStack(spacing: 4) {
                        Text("Общий баланс")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                    Image(systemName: "wallet.bifold.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(.white.opacity(0.18))
                        .clipShape(Circle())
                }

                // Сумма — слева, символ валюты первым
                VStack(alignment: .leading, spacing: 2) {
                    if balances.isEmpty {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text("₽")
                                .font(.title.bold())
                                .foregroundStyle(.white.opacity(0.85))
                            Text("0")
                                .font(.system(size: 42, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    } else if balances.count == 1, let entry = balances.first {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(CurrencyInfo.symbol(for: entry.code, custom: customCurrencies))
                                .font(.title.bold())
                                .foregroundStyle(.white.opacity(0.85))
                            Text(entry.amount, format: .number.precision(.fractionLength(0...2)))
                                .font(.system(size: 42, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    } else {
                        ForEach(balances, id: \.code) { entry in
                            HStack(alignment: .firstTextBaseline, spacing: 3) {
                                Text(CurrencyInfo.symbol(for: entry.code, custom: customCurrencies))
                                    .font(.headline.bold())
                                    .foregroundStyle(.white.opacity(0.85))
                                Text(entry.amount, format: .number.precision(.fractionLength(0...2)))
                                    .font(.title2.bold())
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                }

                // Нижняя строка: доходы | расходы
                HStack(alignment: .top, spacing: 0) {
                    IncomeExpenseColumn(
                        label: "Доходы",
                        entries: incomes,
                        customCurrencies: customCurrencies
                    )

                    Rectangle()
                        .fill(.white.opacity(0.25))
                        .frame(width: 1, height: 36)
                        .padding(.horizontal, 16)
                        .padding(.top, 2)

                    IncomeExpenseColumn(
                        label: "Расходы",
                        entries: expenses,
                        customCurrencies: customCurrencies
                    )

                    Spacer()
                }
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .background(
            LinearGradient(
                colors: [Color(hex: "7B7FF5"), Color(hex: "9333EA")],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: AppTheme.Colors.accent.opacity(0.4), radius: 12, x: 0, y: 6)
    }
}

// MARK: - Столбец доход/расход внутри карточки

private struct IncomeExpenseColumn: View {
    let label: String
    let entries: [(code: String, amount: Decimal)]
    let customCurrencies: [Currency]

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))

            if entries.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("0")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                }
            } else {
                ForEach(entries, id: \.code) { entry in
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(entry.amount, format: .number.precision(.fractionLength(0...2)))
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                        Text(CurrencyInfo.symbol(for: entry.code, custom: customCurrencies))
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
        }
    }
}
