//
//  LoanAnalyticsSection.swift
//  BalancePlaning
//

import SwiftUI

// MARK: - Секция кредитной нагрузки

struct LoanAnalyticsSection: View {
    let activeLoans: [Loan]
    let allPayments: [LoanPayment]
    let monthlyIncome: Double
    let customCurrencies: [Currency]

    private var totalMonthlyPayment: Decimal {
        activeLoans.reduce(.zero) { $0 + $1.monthlyPayment }
    }

    private var totalMonthlyPaymentDouble: Double {
        Double(truncating: NSDecimalNumber(decimal: totalMonthlyPayment))
    }

    private var incomeLoadPercent: Double? {
        guard monthlyIncome > 0 else { return nil }
        return totalMonthlyPaymentDouble / monthlyIncome * 100
    }

    var body: some View {
        guard !activeLoans.isEmpty else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: 0) {
                Text("Кредитная нагрузка")
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                ForEach(Array(activeLoans.enumerated()), id: \.element.id) { index, loan in
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(loan.name)
                                    .font(.subheadline)
                                    .lineLimit(1)

                                let remaining = remainingDebt(for: loan)
                                HStack(alignment: .firstTextBaseline, spacing: 2) {
                                    Text("Остаток:")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(remaining, format: .number.precision(.fractionLength(0...2)))
                                        .font(.caption.bold())
                                        .foregroundStyle(.secondary)
                                    Text(CurrencyInfo.symbol(for: loan.currency, custom: customCurrencies))
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 3) {
                                Text("Платёж в месяц")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                HStack(alignment: .firstTextBaseline, spacing: 2) {
                                    Text(loan.monthlyPayment, format: .number.precision(.fractionLength(0...2)))
                                        .font(.subheadline.bold())
                                        .foregroundStyle(AppTheme.Colors.expense)
                                    Text(CurrencyInfo.symbol(for: loan.currency, custom: customCurrencies))
                                        .font(.caption.bold())
                                        .foregroundStyle(AppTheme.Colors.expense.opacity(0.8))
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)

                        if index < activeLoans.count - 1 {
                            Divider().padding(.leading, 16)
                        }
                    }
                }

                Divider()
                    .padding(.horizontal, 16)

                // Итоговая строка
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("Ежемесячно на кредиты:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(totalMonthlyPayment, format: .number.precision(.fractionLength(0...2)))
                            .font(.subheadline.bold())
                            .foregroundStyle(AppTheme.Colors.expense)
                        Text("₽")
                            .font(.caption.bold())
                            .foregroundStyle(AppTheme.Colors.expense.opacity(0.8))
                    }
                    if let pct = incomeLoadPercent {
                        Text("(\(Int(pct))% дохода)")
                            .font(.caption)
                            .foregroundStyle(pct > 40 ? AppTheme.Colors.expense : .secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        )
    }

    // MARK: - Остаток долга

    private func remainingDebt(for loan: Loan) -> Decimal {
        let paid = allPayments
            .filter { $0.loanId == loan.id }
            .reduce(Decimal.zero) { $0 + $1.totalAmount }
        let remaining = loan.originalAmount - paid
        return remaining > .zero ? remaining : .zero
    }
}
