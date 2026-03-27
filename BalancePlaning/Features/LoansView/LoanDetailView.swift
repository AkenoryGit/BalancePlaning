//
//  LoanDetailView.swift
//  BalancePlaning
//

import SwiftUI
import SwiftData

struct LoanDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(TabBarVisibilityModel.self) private var tabBarVisibility
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
        .onAppear {
            tabBarVisibility.isHidden = true
            // Если в графике есть незапланированные слоты (нет LoanPayment записи) —
            // синхронизируем: создаём недостающие записи и обновляем существующие.
            // Это нужно после изменения логики расчёта (напр. капитализация процентов).
            guard !loan.isArchived else { return }
            let hasUnsyncedSlots = schedule.contains { !$0.isPaid && !$0.isPrepayment && $0.linkedPaymentId == nil }
            if hasUnsyncedSlots {
                service.syncFutureSchedule(for: loan, allPayments: loanPayments)
            }
        }
        .onDisappear {
            tabBarVisibility.isHidden = false
            guard let action = pendingAction else { return }
            pendingAction = nil
            // Откладываем удаление на следующий цикл event loop.
            // context.save() внутри deleteLoan триггерит @Query-обновления во всех живых View.
            // Если удалять синхронно в onDisappear, SwiftUI может обратиться к .type/.priority
            // уже удалённых Transaction во время diff/re-render → "backing data detached" краш.
            Task { @MainActor in action() }
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                BankIconBadge(iconId: loan.iconId, size: 40)
                VStack(alignment: .leading, spacing: 2) {
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
                    statPill(title: "Осталось", value: "\(remainMonths) \(AppSettings.shared.bundle.localizedString(forKey: "мес.", value: "мес.", table: nil))")
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

    private func statPill(title: LocalizedStringKey, value: String) -> some View {
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
        let bundle = AppSettings.shared.bundle
        let moLabel = bundle.localizedString(forKey: "мес.", value: "мес.", table: nil)
        let paLabel = bundle.localizedString(forKey: "годовых", value: "годовых", table: nil)
        let lastDay = bundle.localizedString(forKey: "Последнее число месяца", value: "Последнее число месяца", table: nil)
        let dayLabel: String
        if loan.paymentDay == 0 {
            dayLabel = lastDay
        } else if bundle != Bundle.main {
            dayLabel = "Day \(loan.paymentDay)"
        } else {
            dayLabel = "\(loan.paymentDay)-е число"
        }
        return VStack(spacing: 0) {
            if let borrower = loan.borrowerName, !borrower.isEmpty {
                infoRow(label: "На кого взят", value: borrower)
                Divider().padding(.leading, 16)
            }
            infoRow(label: "Сумма кредита", value: "\(loan.originalAmount.formatted(.number.precision(.fractionLength(0...0)))) \(CurrencyInfo.symbol(for: loan.currency))")
            Divider().padding(.leading, 16)
            infoRow(label: "Процентная ставка", value: "\(LoanService.toDouble(loan.interestRate).formatted(.number.precision(.fractionLength(0...2))))% \(paLabel)")
            Divider().padding(.leading, 16)
            infoRow(label: "Срок", value: "\(loan.termMonths) \(moLabel)")
            Divider().padding(.leading, 16)
            infoRow(label: "Дата выдачи", value: loan.startDate.formatted(.dateTime.day().month(.wide).year().locale(locale)))
            Divider().padding(.leading, 16)
            infoRow(label: "Дата платежа", value: dayLabel)
        }
        .cardStyle()
        .padding(.horizontal)
    }

    private func infoRow(label: LocalizedStringKey, value: String) -> some View {
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
                ScheduleRow(
                    entry: entry,
                    isScheduledFuture: !entry.isPaid && !entry.isPrepayment && entry.linkedPaymentId != nil,
                    onCheck: (!loan.isArchived && !entry.isPaid && !entry.isPrepayment) ? {
                        checkAction(for: entry)
                    } : nil,
                    onUnmark: (entry.isPaid && !entry.isPrepayment) ? {
                        uncheckAction(for: entry)
                    } : nil
                )
            }
            .padding(.bottom, 8)
        }
        .cardStyle()
        .padding(.horizontal)
    }

    // MARK: - Add Payment Bar

    // MARK: - Checkbox actions

    private func checkAction(for entry: LoanScheduleEntry) {
        if let paymentId = entry.linkedPaymentId,
           let payment = allPayments.first(where: { $0.id == paymentId }) {
            service.revertPaymentDate(payment, to: Date())
        } else {
            let paymentDate = entry.date <= Date() ? entry.date : Date()
            service.addPayment(to: loan, date: paymentDate, amount: entry.totalAmount,
                               isPrepayment: false, prepaymentType: nil,
                               fromAccount: nil, allPayments: loanPayments)
        }
    }

    private func uncheckAction(for entry: LoanScheduleEntry) {
        guard let paymentId = entry.linkedPaymentId,
              let payment = allPayments.first(where: { $0.id == paymentId }) else { return }
        if entry.scheduledDate <= Date() {
            // Плановая дата уже прошла — удаляем платёж совсем
            service.deletePayment(payment, loan: loan, allPayments: loanPayments)
        } else {
            // Плановая дата ещё не наступила — возвращаем платёж на плановую дату
            service.revertPaymentDate(payment, to: entry.scheduledDate)
        }
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
    var isScheduledFuture: Bool = false
    var onCheck: (() -> Void)? = nil
    var onUnmark: (() -> Void)? = nil
    @Environment(\.locale) private var locale

    private var action: (() -> Void)? {
        if entry.isPaid { return onUnmark }
        return onCheck
    }

    var body: some View {
        HStack(spacing: 12) {
            if let action {
                Button(action: action) { statusCircle }.buttonStyle(.plain)
            } else {
                statusCircle
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(entry.date, format: .dateTime.day().month(.wide).year().locale(locale))
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
                    let b = AppSettings.shared.bundle
                    let osnLabel = b.localizedString(forKey: "Осн:", value: "Осн:", table: nil)
                    let procLabel = b.localizedString(forKey: "Проц:", value: "Проц:", table: nil)
                    Text("\(osnLabel) \(entry.principalPart, format: .number.precision(.fractionLength(0...0))) ₽  · \(procLabel) \(entry.interestPart, format: .number.precision(.fractionLength(0...0))) ₽")
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

    private var statusCircle: some View {
        ZStack {
            Circle()
                .fill(statusColor.opacity(0.15))
                .frame(width: 32, height: 32)
            Image(systemName: statusIcon)
                .font(.caption.bold())
                .foregroundStyle(statusColor)
        }
    }

    private var statusIcon: String {
        if entry.isPaid { return "checkmark" }
        if entry.isPrepayment { return "clock" }
        if isScheduledFuture { return "circle.dotted" }
        if entry.date < Date() { return "exclamationmark" }
        return "circle"
    }

    private var statusColor: Color {
        if entry.isPaid { return AppTheme.Colors.income }
        if isScheduledFuture { return AppTheme.Colors.accent }
        if entry.date < Date() { return AppTheme.Colors.expense }
        return .secondary
    }
}
