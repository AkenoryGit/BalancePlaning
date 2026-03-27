//
//  LoanPaymentFromMainSheet.swift
//  BalancePlaning
//

import SwiftUI
import SwiftData

// MARK: - Выбор кредита → форма платежа (вызывается с главного экрана)

struct LoanPaymentFromMainSheet: View {
    @Binding var isRootPresented: Bool
    @Environment(\.dismiss) private var dismiss
    @Query private var allLoans: [Loan]

    private var activeLoans: [Loan] {
        guard let uid = currentUserId() else { return [] }
        return allLoans.filter { $0.userId == uid && !$0.isArchived }
    }

    var body: some View {
        NavigationStack {
            Group {
                if activeLoans.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "creditcard")
                            .font(.system(size: 48))
                            .foregroundStyle(Color(hex: "E74C3C").opacity(0.4))
                        Text("Нет активных кредитов")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("Добавьте кредит в разделе «Кредиты»")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(activeLoans) { loan in
                                NavigationLink(value: loan) {
                                    LoanPickerCard(loan: loan)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }
                }
            }
            .background(AppTheme.Colors.pageBackground)
            .navigationTitle("Платёж по кредиту")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Закрыть") { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
            .navigationDestination(for: Loan.self) { loan in
                LoanPaymentFormView(loan: loan, onSaved: { isRootPresented = false })
            }
        }
    }
}

// MARK: - Карточка выбора кредита

private struct LoanPickerCard: View {
    let loan: Loan
    @Query private var allPayments: [LoanPayment]
    @Environment(\.modelContext) private var context

    private var service: LoanService { LoanService(context: context) }
    private var payments: [LoanPayment] { allPayments.filter { $0.loanId == loan.id } }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "creditcard.fill")
                .font(.title3)
                .foregroundStyle(Color(hex: "E74C3C"))
                .frame(width: 44, height: 44)
                .background(Color(hex: "E74C3C").opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(loan.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                let remaining = service.remainingPrincipal(for: loan, payments: payments)
                (Text("Остаток: ") + Text(remaining, format: .number.precision(.fractionLength(0...0))) + Text(" \(CurrencyInfo.symbol(for: loan.currency))"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .cardStyle()
    }
}

// MARK: - Форма платежа (без NavigationStack — встраивается как destination)

struct LoanPaymentFormView: View {
    let loan: Loan
    let onSaved: () -> Void

    @Environment(\.modelContext) private var context
    @Query private var allPayments: [LoanPayment]
    @Query private var allAccounts: [Account]

    @State private var isPrepayment = false
    @State private var prepaymentType: PrepaymentType = .reduceTerm
    @State private var amountStr: String = ""
    @State private var paymentDate: Date = Date()
    @State private var selectedAccountId: UUID? = nil
    @State private var comment: String = ""
    @State private var showAmountError = false

    @State private var useRecurring = false
    @State private var recurringInterval: RecurringInterval = .monthly
    @State private var recurringIntervalDays: Int = 7
    @State private var recurringEndDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()

    private var service: LoanService { LoanService(context: context) }

    private var userAccounts: [Account] {
        guard let uid = currentUserId() else { return [] }
        return allAccounts.filter { $0.userId == uid }
    }

    private var loanPayments: [LoanPayment] { allPayments.filter { $0.loanId == loan.id } }

    private var amount: Decimal? {
        Decimal(string: amountStr.replacingOccurrences(of: ",", with: "."))
    }

    private var selectedAccount: Account? {
        guard let id = selectedAccountId else { return nil }
        return userAccounts.first { $0.id == id }
    }

    private var defaultAmount: Decimal {
        service.currentMonthlyPayment(for: loan, payments: allPayments)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // Тип платежа
                VStack(spacing: 0) {
                    Toggle(isOn: $isPrepayment.animation()) {
                        HStack(spacing: 10) {
                            Image(systemName: isPrepayment ? "arrow.up.forward.circle.fill" : "calendar.circle.fill")
                                .foregroundStyle(Color(hex: "E74C3C"))
                                .frame(width: 20)
                            Text(LocalizedStringKey(isPrepayment ? "Досрочное погашение" : "Плановый платёж"))
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)

                    if isPrepayment {
                        Divider().padding(.leading, 16)
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                .foregroundStyle(Color(hex: "E74C3C"))
                                .frame(width: 20)
                            Text("Направить на")
                            Spacer()
                            Picker("", selection: $prepaymentType) {
                                Text("Уменьш. срок").tag(PrepaymentType.reduceTerm)
                                Text("Уменьш. платёж").tag(PrepaymentType.reducePayment)
                            }
                            .labelsHidden()
                            .tint(Color(hex: "E74C3C"))
                        }
                        .padding(.horizontal, 16).padding(.vertical, 10)
                    }
                }
                .cardStyle()
                .padding(.horizontal)

                // Блок повторения (только для досрочных погашений)
                if isPrepayment {
                    VStack(spacing: 0) {
                        Toggle(isOn: $useRecurring.animation()) {
                            HStack(spacing: 10) {
                                Image(systemName: "repeat.circle.fill")
                                    .foregroundStyle(Color(hex: "E74C3C"))
                                    .frame(width: 20)
                                Text("Повторять")
                            }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)

                        if useRecurring {
                            Divider().padding(.leading, 16)
                            HStack(spacing: 12) {
                                Image(systemName: "calendar.badge.clock")
                                    .foregroundStyle(Color(hex: "E74C3C"))
                                    .frame(width: 20)
                                Text("Период")
                                Spacer()
                                Picker("", selection: $recurringInterval) {
                                    Text("Ежемесячно").tag(RecurringInterval.monthly)
                                    Text("Каждые 2 нед.").tag(RecurringInterval.biweekly)
                                    Text("Еженедельно").tag(RecurringInterval.weekly)
                                    Text("Ежедневно").tag(RecurringInterval.daily)
                                    Text("Каждые N дней").tag(RecurringInterval.everyNDays)
                                }
                                .labelsHidden()
                                .tint(Color(hex: "E74C3C"))
                            }
                            .padding(.horizontal, 16).padding(.vertical, 10)

                            if recurringInterval == .everyNDays {
                                Divider().padding(.leading, 44)
                                HStack(spacing: 12) {
                                    Spacer().frame(width: 32)
                                    Text("Каждые").foregroundStyle(.secondary)
                                    Spacer()
                                    Stepper("\(recurringIntervalDays) дн.", value: $recurringIntervalDays, in: 1...365)
                                        .fixedSize()
                                }
                                .padding(.horizontal, 16).padding(.vertical, 10)
                            }

                            Divider().padding(.leading, 16)
                            HStack(spacing: 12) {
                                Image(systemName: "calendar.badge.checkmark")
                                    .foregroundStyle(Color(hex: "E74C3C"))
                                    .frame(width: 20)
                                Text("До даты")
                                Spacer()
                                DatePicker("", selection: $recurringEndDate,
                                           in: paymentDate...,
                                           displayedComponents: [.date])
                                    .labelsHidden()
                            }
                            .padding(.horizontal, 16).padding(.vertical, 10)
                        }
                    }
                    .cardStyle()
                    .padding(.horizontal)
                }

                // Сумма и дата
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Image(systemName: "rublesign")
                            .foregroundStyle(Color(hex: "E74C3C"))
                            .frame(width: 20)
                        TextField("Сумма", text: $amountStr)
                            .keyboardType(.decimalPad)
                            .foregroundStyle(showAmountError ? .red : .primary)
                            .overlay(alignment: .leading) {
                                if amountStr.isEmpty {
                                    Text("\(defaultAmount, format: .number.precision(.fractionLength(0...0)))")
                                        .foregroundStyle(.quaternary)
                                        .allowsHitTesting(false)
                                }
                            }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)

                    if showAmountError {
                        Text("Введите сумму больше нуля")
                            .font(.caption).foregroundStyle(.red)
                            .padding(.horizontal, 16).padding(.bottom, 8)
                    }

                    Divider().padding(.leading, 16)

                    HStack(spacing: 12) {
                        Image(systemName: "calendar")
                            .foregroundStyle(Color(hex: "E74C3C"))
                            .frame(width: 20)
                        Text(useRecurring && isPrepayment ? "Начальная дата" : "Дата")
                        Spacer()
                        DatePicker("", selection: $paymentDate, displayedComponents: [.date])
                            .labelsHidden()
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                }
                .cardStyle()
                .padding(.horizontal)

                // Счёт списания
                if !userAccounts.isEmpty {
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            Image(systemName: "creditcard")
                                .foregroundStyle(Color(hex: "E74C3C"))
                                .frame(width: 20)
                            Text("Списать со счёта")
                            Spacer()
                            Menu {
                                Button("Не указывать") { selectedAccountId = nil }
                                ForEach(userAccounts) { acc in
                                    Button(acc.name) { selectedAccountId = acc.id }
                                }
                            } label: {
                                Group {
                                    if let acc = selectedAccount { Text(acc.name) } else { Text("Не указывать") }
                                }
                                .foregroundStyle(.secondary)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2).foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)
                    }
                    .cardStyle()
                    .padding(.horizontal)
                }

                // Комментарий
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Image(systemName: "text.alignleft")
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        TextField("Комментарий (необязательно)", text: $comment)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                }
                .cardStyle()
                .padding(.horizontal)

                // Предварительный расчёт для досрочного платежа
                if isPrepayment, let amt = amount, amt > 0 {
                    prepaymentPreview(amount: amt)
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(AppTheme.Colors.pageBackground)
        .navigationTitle(LocalizedStringKey(isPrepayment ? "Досрочное погашение" : "Внести платёж"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Сохранить") { save() }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(hex: "E74C3C"))
            }
        }
        .onAppear {
            if !isPrepayment {
                let dbl = LoanService.toDouble(defaultAmount)
                if dbl > 0 { amountStr = "\(Int(dbl))" }
            }
        }
    }

    private func prepaymentPreview(amount: Decimal) -> some View {
        let tempPayments = Array(allPayments) + [LoanPayment(
            loanId: loan.id, userId: currentUserId() ?? UUID(),
            date: paymentDate, totalAmount: amount,
            isPrepayment: true, prepaymentType: prepaymentType
        )]
        let beforeRemaining = service.remainingPrincipal(for: loan, payments: Array(allPayments))
        let afterRemaining  = service.remainingPrincipal(for: loan, payments: tempPayments)
        let beforeMonths    = service.remainingMonths(for: loan, payments: Array(allPayments))
        let afterMonths     = service.remainingMonths(for: loan, payments: tempPayments)
        let beforeMonthly   = service.currentMonthlyPayment(for: loan, payments: Array(allPayments))
        let afterMonthly    = service.currentMonthlyPayment(for: loan, payments: tempPayments)

        let sym = CurrencyInfo.symbol(for: loan.currency)
        return VStack(alignment: .leading, spacing: 0) {
            Text("Предварительный расчёт")
                .font(.caption).foregroundStyle(.secondary)
                .padding(.horizontal, 16).padding(.top, 12)

            Divider().padding(.horizontal, 16).padding(.top, 8)

            HStack {
                previewColumn(title: "Долг до", value: "\(beforeRemaining.formatted(.number.precision(.fractionLength(0...0)))) \(sym)")
                Image(systemName: "arrow.right").foregroundStyle(.secondary)
                previewColumn(title: "Долг после", value: "\(afterRemaining.formatted(.number.precision(.fractionLength(0...0)))) \(sym)", highlight: true)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)

            Divider().padding(.horizontal, 16)

            if prepaymentType == .reduceTerm {
                let moLabel = AppSettings.shared.bundle.localizedString(forKey: "мес.", value: "мес.", table: nil)
                HStack {
                    previewColumn(title: "Срок до", value: "\(beforeMonths) \(moLabel)")
                    Image(systemName: "arrow.right").foregroundStyle(.secondary)
                    previewColumn(title: "Срок после", value: "\(afterMonths) \(moLabel)", highlight: true)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
            } else {
                HStack {
                    previewColumn(title: "Платёж до", value: "\(beforeMonthly.formatted(.number.precision(.fractionLength(0...0)))) \(sym)")
                    Image(systemName: "arrow.right").foregroundStyle(.secondary)
                    previewColumn(title: "Платёж после", value: "\(afterMonthly.formatted(.number.precision(.fractionLength(0...0)))) \(sym)", highlight: true)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
            }
        }
        .padding(.bottom, 4)
        .cardStyle()
        .padding(.horizontal)
    }

    private func previewColumn(title: LocalizedStringKey, value: String, highlight: Bool = false) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.subheadline.bold())
                .foregroundStyle(highlight ? AppTheme.Colors.income : .primary)
        }
        .frame(maxWidth: .infinity)
    }

    private func save() {
        let finalAmount: Decimal
        if let a = amount, a > 0 {
            finalAmount = a
        } else if !amountStr.isEmpty {
            showAmountError = true; return
        } else {
            finalAmount = defaultAmount
        }
        guard finalAmount > 0 else { showAmountError = true; return }

        if isPrepayment && useRecurring {
            service.addRecurringPrepayments(
                to: loan,
                startDate: paymentDate,
                endDate: recurringEndDate,
                amount: finalAmount,
                prepaymentType: prepaymentType,
                fromAccount: selectedAccount,
                interval: recurringInterval,
                intervalDays: recurringIntervalDays,
                allPayments: Array(allPayments),
                comment: comment
            )
        } else {
            service.addPayment(
                to: loan,
                date: paymentDate,
                amount: finalAmount,
                isPrepayment: isPrepayment,
                prepaymentType: isPrepayment ? prepaymentType : nil,
                fromAccount: selectedAccount,
                allPayments: Array(allPayments),
                comment: comment
            )
        }
        onSaved()
    }
}

// MARK: - Редактирование существующего платежа по кредиту

struct EditLoanPaymentSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let transaction: Transaction

    @Query private var allPayments: [LoanPayment]
    @Query private var allAccounts: [Account]
    @Query private var allLoans: [Loan]

    @State private var amountStr: String
    @State private var paymentDate: Date
    @State private var selectedAccountId: UUID?
    @State private var comment: String
    @State private var showAmountError = false
    @State private var showCancelSeriesAlert = false

    init(transaction: Transaction) {
        self.transaction = transaction
        _amountStr         = State(initialValue: NSDecimalNumber(decimal: transaction.amount).stringValue)
        _paymentDate       = State(initialValue: transaction.date)
        _selectedAccountId = State(initialValue: transaction.fromAccount?.id)
        _comment           = State(initialValue: transaction.comment)
    }

    private var userAccounts: [Account] {
        guard let uid = currentUserId() else { return [] }
        return allAccounts.filter { $0.userId == uid }
    }

    private var selectedAccount: Account? {
        guard let id = selectedAccountId else { return nil }
        return userAccounts.first { $0.id == id }
    }

    private var amount: Decimal? {
        Decimal(string: amountStr.replacingOccurrences(of: ",", with: "."))
    }

    // Находим LoanPayment по loanId + дата (до изменения даты транзакции)
    private var linkedPayment: LoanPayment? {
        guard let loanId = transaction.loanId else { return nil }
        return allPayments.first {
            $0.loanId == loanId &&
            Calendar.current.isDate($0.date, inSameDayAs: transaction.date)
        }
    }

    private var linkedLoan: Loan? {
        guard let loanId = transaction.loanId else { return nil }
        return allLoans.first { $0.id == loanId }
    }

    private var isPartOfSeries: Bool {
        linkedPayment?.recurringGroupId != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            Image(systemName: "rublesign")
                                .foregroundStyle(Color(hex: "E74C3C"))
                                .frame(width: 20)
                            TextField("Сумма", text: $amountStr)
                                .keyboardType(.decimalPad)
                                .foregroundStyle(showAmountError ? .red : .primary)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)

                        if showAmountError {
                            Text("Введите сумму больше нуля")
                                .font(.caption).foregroundStyle(.red)
                                .padding(.horizontal, 16).padding(.bottom, 8)
                        }

                        Divider().padding(.leading, 16)

                        HStack(spacing: 12) {
                            Image(systemName: "calendar")
                                .foregroundStyle(Color(hex: "E74C3C"))
                                .frame(width: 20)
                            Text("Дата")
                            Spacer()
                            DatePicker("", selection: $paymentDate, displayedComponents: [.date])
                                .labelsHidden()
                        }
                        .padding(.horizontal, 16).padding(.vertical, 10)
                    }
                    .cardStyle()
                    .padding(.horizontal)

                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            Image(systemName: "creditcard")
                                .foregroundStyle(Color(hex: "E74C3C"))
                                .frame(width: 20)
                            Text("Списать со счёта")
                            Spacer()
                            Menu {
                                Button("—  Не указывать") { selectedAccountId = nil }
                                if !userAccounts.isEmpty { Divider() }
                                ForEach(userAccounts) { acc in
                                    Button(acc.name) { selectedAccountId = acc.id }
                                }
                            } label: {
                                Text(selectedAccount?.name ?? "—")
                                    .foregroundStyle(.secondary)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2).foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)
                    }
                    .cardStyle()
                    .padding(.horizontal)

                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            Image(systemName: "text.alignleft")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            TextField("Комментарий (необязательно)", text: $comment)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)
                    }
                    .cardStyle()
                    .padding(.horizontal)

                    // Кнопка отмены серии (только для повторяющихся досрочных погашений)
                    if isPartOfSeries {
                        Button(role: .destructive) {
                            showCancelSeriesAlert = true
                        } label: {
                            Label("Отменить эту и последующие", systemImage: "xmark.circle")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color(.systemRed).opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonRadius))
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(AppTheme.Colors.pageBackground)
            .navigationTitle("Редактировать платёж")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Сохранить") { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color(hex: "E74C3C"))
                }
            }
            .alert("Отменить серию?", isPresented: $showCancelSeriesAlert) {
                Button("Удалить эту и последующие", role: .destructive) {
                    cancelSeries()
                }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Этот и все последующие запланированные платежи серии будут удалены")
            }
        }
    }

    private func save() {
        guard let amt = amount, amt > 0 else { showAmountError = true; return }

        // Обновляем LoanPayment до изменения даты транзакции
        if let payment = linkedPayment {
            payment.fromAccountId = selectedAccount?.id
            payment.totalAmount = amt
            payment.date = paymentDate
        }

        transaction.fromAccount = selectedAccount
        transaction.amount = amt
        transaction.date = paymentDate
        transaction.comment = comment
        try? context.save()
        dismiss()
    }

    private func cancelSeries() {
        guard let payment = linkedPayment,
              let groupId = payment.recurringGroupId,
              let loan = linkedLoan else { dismiss(); return }
        let loanPayments = allPayments.filter { $0.loanId == loan.id }
        LoanService(context: context).deleteRecurringPrepayments(
            groupId: groupId,
            from: payment.date,
            loan: loan,
            allPayments: loanPayments
        )
        dismiss()
    }
}
