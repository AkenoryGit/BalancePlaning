//
//  LoanDetailView.swift
//  BalancePlaning
//

import SwiftUI
import SwiftData

struct LoanDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let loan: Loan

    @Query private var allPayments: [LoanPayment]
    @Query private var allAccounts: [Account]

    @State private var showEdit = false
    @State private var showAddPayment = false
    @State private var showDeleteAlert = false
    @State private var pendingAction: (() -> Void)?

    private var service: LoanService { LoanService(context: context) }

    private var loanPayments: [LoanPayment] {
        allPayments.filter { $0.loanId == loan.id }
    }
    private var schedule: [LoanScheduleEntry] {
        service.generateSchedule(for: loan, payments: allPayments)
    }
    private var remaining: Decimal { service.remainingPrincipal(for: loan, payments: allPayments) }
    private var monthly: Decimal { service.currentMonthlyPayment(for: loan, payments: allPayments) }
    private var overpayment: Decimal { service.totalOverpayment(for: loan, payments: allPayments) }
    private var remainMonths: Int { service.remainingMonths(for: loan, payments: allPayments) }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                headerCard

                infoCard

                scheduleSection
            }
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .background(AppTheme.Colors.pageBackground)
        .navigationTitle(loan.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showEdit = true } label: {
                        Label("Редактировать", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("Удалить кредит", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !loan.isArchived {
                addPaymentBar
            }
        }
        .sheet(isPresented: $showEdit) {
            AddLoanSheet(loan: loan)
        }
        .sheet(isPresented: $showAddPayment) {
            AddLoanPaymentSheet(loan: loan)
        }
        .alert("Удалить кредит «\(loan.name)»?", isPresented: $showDeleteAlert) {
            Button("Удалить", role: .destructive) {
                pendingAction = { LoanService(context: context).deleteLoan(loan, allPayments: loanPayments) }
                dismiss()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Удалятся все платежи по этому кредиту")
        }
        .onDisappear {
            pendingAction?()
            pendingAction = nil
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(spacing: 12) {
            VStack(spacing: 4) {
                Text("Остаток долга")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("−")
                        .font(.system(size: 32, weight: .bold))
                    Text(remaining, format: .number.precision(.fractionLength(0...0)))
                        .font(.system(size: 32, weight: .bold))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text(" \(CurrencyInfo.symbol(for: loan.currency))")
                        .font(.title2.bold())
                }
                .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if loan.isArchived {
                Label("Кредит погашен", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.15))
                    .clipShape(Capsule())
            } else {
                HStack(spacing: 10) {
                    statPill(title: "Платёж/мес",
                             value: "\(monthly.formatted(.number.precision(.fractionLength(0...0)))) \(CurrencyInfo.symbol(for: loan.currency))")
                    statPill(title: "Осталось", value: "\(remainMonths) мес.")
                    statPill(title: "Переплата",
                             value: "\(overpayment.formatted(.number.precision(.fractionLength(0...0)))) \(CurrencyInfo.symbol(for: loan.currency))")
                }
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color(hex: "C0392B"), Color(hex: "E74C3C")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color(hex: "C0392B").opacity(0.35), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }

    private func statPill(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
            Text(value)
                .font(.caption.bold())
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.white.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Info

    private var infoCard: some View {
        VStack(spacing: 0) {
            infoRow(label: "Сумма кредита", value: "\(loan.originalAmount.formatted(.number.precision(.fractionLength(0...0)))) \(CurrencyInfo.symbol(for: loan.currency))")
            Divider().padding(.leading, 16)
            infoRow(label: "Процентная ставка", value: "\(LoanService.toDouble(loan.interestRate).formatted(.number.precision(.fractionLength(0...2))))% годовых")
            Divider().padding(.leading, 16)
            infoRow(label: "Срок", value: "\(loan.termMonths) мес.")
            Divider().padding(.leading, 16)
            infoRow(label: "Дата выдачи", value: loan.startDate.formatted(.dateTime.locale(Locale(identifier: "ru_RU")).day().month(.wide).year()))
            Divider().padding(.leading, 16)
            infoRow(label: "Дата платежа", value: "\(loan.paymentDay)-е число")
        }
        .cardStyle()
        .padding(.horizontal)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    // MARK: - Schedule

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("График платежей")
                .font(.headline)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)

            ForEach(Array(schedule.enumerated()), id: \.element.id) { idx, entry in
                if idx > 0 {
                    Divider().padding(.leading, 56)
                }
                ScheduleRow(entry: entry)
            }
            .padding(.bottom, 8)
        }
        .cardStyle()
        .padding(.horizontal)
    }

    // MARK: - Add Payment Bar

    private var addPaymentBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                Button {
                    showAddPayment = true
                } label: {
                    Label("Внести платёж", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "C0392B"), Color(hex: "E74C3C")],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonRadius))
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(.secondarySystemGroupedBackground))
    }
}

// MARK: - Строка графика

private struct ScheduleRow: View {
    let entry: LoanScheduleEntry

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: statusIcon)
                    .font(.caption.bold())
                    .foregroundStyle(statusColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(entry.date, format: .dateTime.locale(Locale(identifier: "ru_RU")).day().month(.wide).year())
                        .font(.subheadline)
                        .foregroundStyle(entry.isPaid ? .secondary : .primary)

                    if entry.isPrepayment {
                        Text("Досрочный")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.Colors.accent)
                            .clipShape(Capsule())
                    }
                }

                if !entry.isPrepayment {
                    Text("Осн: \(entry.principalPart, format: .number.precision(.fractionLength(0...0))) ₽  · Проц: \(entry.interestPart, format: .number.precision(.fractionLength(0...0))) ₽")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(entry.totalAmount, format: .number.precision(.fractionLength(0...0))) ₽")
                    .font(.subheadline.bold())
                    .foregroundStyle(entry.isPaid ? .secondary : .primary)
                Text("→ \(entry.remainingAfter, format: .number.precision(.fractionLength(0...0))) ₽")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var statusIcon: String {
        if entry.isPaid { return "checkmark" }
        if entry.date < Date() { return "exclamationmark" }
        return "clock"
    }

    private var statusColor: Color {
        if entry.isPaid { return AppTheme.Colors.income }
        if entry.date < Date() { return AppTheme.Colors.expense }
        return .secondary
    }
}
