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

    // Максимум 6 валют: до 3 — столбик, 4–6 — два столбика
    private var displayedBalances: [(code: String, amount: Decimal)] {
        Array(balances.prefix(6))
    }

    var body: some View {
        Button(action: { onBalanceTap?() }) {
            VStack(alignment: .leading, spacing: 6) {

                // Верхняя строка: метка + кошелёк
                HStack(alignment: .center) {
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
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.18))
                        .clipShape(Circle())
                }

                // Сумма баланса
                balanceSection

                // Доходы | Расходы — два равных блока
                HStack(alignment: .top, spacing: 0) {
                    incomeExpenseBlock(label: "Доходы", entries: incomes)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    incomeExpenseBlock(label: "Расходы", entries: expenses)
                        .frame(maxWidth: .infinity, alignment: .leading)
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

    // MARK: - Секция баланса

    @ViewBuilder
    private var balanceSection: some View {
        let count = displayedBalances.count
        if count <= 1 {
            // Одна валюта — крупно
            let entry = displayedBalances.first
            let symbol = entry.map { CurrencyInfo.symbol(for: $0.code, custom: customCurrencies) } ?? "₽"
            let amount = entry?.amount ?? 0
            balanceRow(symbol: symbol, amount: amount, numSize: 50, symSize: 28)
        } else if count <= 3 {
            // 2–3 валюты — стопкой, высота делится
            let numSize: CGFloat = count == 2 ? 36 : 28
            let symSize: CGFloat = count == 2 ? 22 : 17
            VStack(alignment: .leading, spacing: 2) {
                ForEach(displayedBalances, id: \.code) { entry in
                    balanceRow(
                        symbol: CurrencyInfo.symbol(for: entry.code, custom: customCurrencies),
                        amount: entry.amount,
                        numSize: numSize,
                        symSize: symSize
                    )
                }
            }
        } else {
            // 4–6 валют — два столбика
            let half = (count + 1) / 2
            let left  = Array(displayedBalances.prefix(half))
            let right = Array(displayedBalances.suffix(count - half))
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(left, id: \.code) { entry in
                        balanceRow(
                            symbol: CurrencyInfo.symbol(for: entry.code, custom: customCurrencies),
                            amount: entry.amount,
                            numSize: 22,
                            symSize: 13
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(right, id: \.code) { entry in
                        balanceRow(
                            symbol: CurrencyInfo.symbol(for: entry.code, custom: customCurrencies),
                            amount: entry.amount,
                            numSize: 22,
                            symSize: 13
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func balanceRow(symbol: String, amount: Decimal, numSize: CGFloat, symSize: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(symbol)
                .font(.system(size: symSize, weight: .bold))
                .foregroundStyle(.white.opacity(0.85))
            Text(amount, format: .number.precision(.fractionLength(0...2)))
                .font(.system(size: numSize, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Блок доход/расход

    private func incomeExpenseBlock(label: String, entries: [(code: String, amount: Decimal)]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))

            if entries.isEmpty {
                Text("0")
                    .font(.callout.bold())
                    .foregroundStyle(.white)
            } else {
                ForEach(entries, id: \.code) { entry in
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(CurrencyInfo.symbol(for: entry.code, custom: customCurrencies))
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.8))
                        Text(entry.amount, format: .number.precision(.fractionLength(0...2)))
                            .font(.callout.bold())
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }
}
