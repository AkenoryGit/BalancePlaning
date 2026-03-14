//
//  LoansView.swift
//  BalancePlaning
//

import SwiftUI
import SwiftData

struct LoansView: View {
    @Environment(\.modelContext) private var context
    @Query private var allLoans: [Loan]
    @Query private var allPayments: [LoanPayment]
    @Query private var allAccounts: [Account]

    @State private var showAddLoan = false
    @State private var showArchived = false

    private var service: LoanService { LoanService(context: context) }

    private var userLoans: [Loan] {
        guard let uid = currentUserId() else { return [] }
        return allLoans.filter { $0.userId == uid }
    }
    private var activeLoans: [Loan] { userLoans.filter { !$0.isArchived } }
    private var archivedLoans: [Loan] { userLoans.filter { $0.isArchived } }

    private var userPayments: [LoanPayment] {
        guard let uid = currentUserId() else { return [] }
        return allPayments.filter { $0.userId == uid }
    }

    private var summaryByCurrency: [(code: String, principal: Decimal, cost: Decimal)] {
        var dict: [String: (principal: Decimal, cost: Decimal)] = [:]
        for loan in activeLoans {
            let principal = service.remainingPrincipal(for: loan, payments: userPayments)
            let cost = service.totalRemainingCost(for: loan, payments: userPayments)
            var cur = dict[loan.currency] ?? (.zero, .zero)
            cur.principal += principal
            cur.cost += cost
            dict[loan.currency] = cur
        }
        return dict.map { (code: $0.key, principal: $0.value.principal, cost: $0.value.cost) }
            .sorted { $0.code < $1.code }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    if activeLoans.isEmpty && archivedLoans.isEmpty {
                        emptyState
                    } else {
                        if !activeLoans.isEmpty {
                            summaryCard
                                .padding(.horizontal)
                        }

                        if !activeLoans.isEmpty {
                            VStack(spacing: 10) {
                                ForEach(activeLoans) { loan in
                                    NavigationLink {
                                        LoanDetailView(loan: loan)
                                    } label: {
                                        LoanCard(loan: loan, payments: userPayments, service: service)
                                            .padding(.horizontal)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        if !archivedLoans.isEmpty {
                            VStack(spacing: 8) {
                                Button {
                                    withAnimation { showArchived.toggle() }
                                } label: {
                                    HStack {
                                        Text("Закрытые кредиты (\(archivedLoans.count))")
                                            .font(.subheadline.bold())
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Image(systemName: showArchived ? "chevron.up" : "chevron.down")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, 20)
                                }
                                .buttonStyle(.plain)

                                if showArchived {
                                    ForEach(archivedLoans) { loan in
                                        NavigationLink {
                                            LoanDetailView(loan: loan)
                                        } label: {
                                            LoanCard(loan: loan, payments: userPayments, service: service)
                                                .padding(.horizontal)
                                                .opacity(0.6)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
            .background(AppTheme.Colors.pageBackground)
            .navigationTitle("Кредиты")
            .navigationBarTitleDisplayMode(.large)
            .overlay(alignment: .bottomTrailing) {
                Button { showAddLoan = true } label: {
                    Image(systemName: "plus")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .frame(width: 58, height: 58)
                        .background(
                            LinearGradient(
                                colors: [AppTheme.Colors.accent, AppTheme.Colors.accentSecondary],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Circle())
                        .shadow(color: AppTheme.Colors.accent.opacity(0.4), radius: 10, x: 0, y: 5)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
        }
        .sheet(isPresented: $showAddLoan) {
            AddLoanSheet()
        }
    }

    private var summaryCard: some View {
        VStack(spacing: 12) {
            ForEach(summaryByCurrency, id: \.code) { entry in
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Общий долг")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(entry.principal, format: .number.precision(.fractionLength(0...0)))
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                            Text(CurrencyInfo.symbol(for: entry.code))
                                .font(.subheadline.bold())
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Divider()
                        .frame(height: 40)
                        .background(.white.opacity(0.3))
                        .padding(.horizontal, 16)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("С переплатой")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(entry.cost, format: .number.precision(.fractionLength(0...0)))
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                            Text(CurrencyInfo.symbol(for: entry.code))
                                .font(.subheadline.bold())
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                colors: [Color(hex: "C0392B"), Color(hex: "E74C3C")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color(hex: "C0392B").opacity(0.4), radius: 10, x: 0, y: 5)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "creditcard.and.123")
                .font(.system(size: 52))
                .foregroundStyle(.quaternary)
            Text("Кредитов нет")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Добавьте кредит или ипотеку,\nчтобы отслеживать платежи")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}

// MARK: - Карточка кредита в списке

private struct LoanCard: View {
    let loan: Loan
    let payments: [LoanPayment]
    let service: LoanService

    private var remaining: Decimal { service.remainingPrincipal(for: loan, payments: payments) }
    private var monthly: Decimal { service.currentMonthlyPayment(for: loan, payments: payments) }
    private var months: Int { service.remainingMonths(for: loan, payments: payments) }
    private var nextDate: Date? { service.nextPaymentDate(for: loan, payments: payments) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: loan.isArchived ? "checkmark.circle.fill" : "creditcard.fill")
                    .font(.title3)
                    .foregroundStyle(loan.isArchived ? AppTheme.Colors.income : Color(hex: "E74C3C"))
                    .frame(width: 44, height: 44)
                    .background((loan.isArchived ? AppTheme.Colors.income : Color(hex: "E74C3C")).opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(loan.name)
                        .font(.subheadline.bold())
                    Text(loan.isArchived ? "Погашен" : "\(LoanService.toDouble(loan.interestRate).formatted(.number.precision(.fractionLength(0...2))))% · \(loan.termMonths) мес.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text("−")
                            .font(.subheadline.bold())
                        Text(remaining, format: .number.precision(.fractionLength(0...0)))
                            .font(.subheadline.bold())
                        Text(" \(CurrencyInfo.symbol(for: loan.currency))")
                            .font(.caption.bold())
                    }
                    .foregroundStyle(Color(hex: "E74C3C"))

                    if !loan.isArchived {
                        Text("\(monthly, format: .number.precision(.fractionLength(0...0))) \(CurrencyInfo.symbol(for: loan.currency))/мес")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(14)

            if !loan.isArchived, let next = nextDate {
                Divider().padding(.horizontal, 14)
                HStack {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Следующий платёж:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(next, format: .dateTime.locale(Locale(identifier: "ru_RU")).day().month(.wide))
                        .font(.caption.bold())
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("Осталось: \(months) мес.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
        .cardStyle()
    }
}
