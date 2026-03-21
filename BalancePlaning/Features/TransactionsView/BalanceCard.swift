//
//  BalanceCard.swift
//  BalancePlaning
//

import SwiftUI
import SwiftData

// MARK: - Карточка баланса (градиентная)

struct BalanceCard: View {
    let balances: [(code: String, amount: Decimal)]
    @Binding var date: Date
    let showNavigation: Bool
    let customCurrencies: [Currency]
    let onDateTap: () -> Void
    var onBalanceTap: (() -> Void)? = nil
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(spacing: 12) {
            Button(action: { onBalanceTap?() }) {
                VStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Text("Общий баланс")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.6))
                    }

                    if balances.isEmpty {
                        Text("0 ₽")
                            .font(.system(size: 52, weight: .bold))
                            .foregroundStyle(.white)
                    } else if balances.count == 1, let entry = balances.first {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(entry.amount, format: .number.precision(.fractionLength(0...2)))
                                .font(.system(size: 52, weight: .bold))
                                .foregroundStyle(.white)
                            Text(CurrencyInfo.symbol(for: entry.code, custom: customCurrencies))
                                .font(.title.bold())
                                .foregroundStyle(.white.opacity(0.85))
                        }
                    } else {
                        VStack(spacing: 4) {
                            ForEach(balances, id: \.code) { entry in
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text(entry.amount, format: .number.precision(.fractionLength(0...2)))
                                        .font(.title2.bold())
                                        .foregroundStyle(.white)
                                    Text(CurrencyInfo.symbol(for: entry.code, custom: customCurrencies))
                                        .font(.headline.bold())
                                        .foregroundStyle(.white.opacity(0.85))
                                }
                            }
                        }
                    }
                }
            }
            .buttonStyle(.plain)

            if showNavigation {
                HStack(spacing: 10) {
                    Button {
                        date = Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(.white.opacity(0.2))
                            .clipShape(Circle())
                    }

                    Button(action: onDateTap) {
                        Text(date.formatted(.dateTime
                            .day(.defaultDigits)
                            .month(.wide)
                            .year(.defaultDigits)
                            .locale(locale)
                        ))
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(.white.opacity(0.2))
                        .clipShape(Capsule())
                    }

                    Button {
                        date = Calendar.current.date(byAdding: .day, value: +1, to: date) ?? date
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [AppTheme.Colors.accent, AppTheme.Colors.accentSecondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: AppTheme.Colors.accent.opacity(0.4), radius: 12, x: 0, y: 6)
    }
}
