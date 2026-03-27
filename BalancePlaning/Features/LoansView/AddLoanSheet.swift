//
//  AddLoanSheet.swift
//  BalancePlaning
//

import SwiftUI
import SwiftData

// MARK: - Черновик записи графика (для редактора перед созданием)

struct DraftEntry: Identifiable {
    let id = UUID()
    let paymentNumber: Int
    var date: Date
    var amountStr: String
    var isIncluded: Bool = true
    var isManuallyAdded: Bool = false
    var isScheduled: Bool = false
    var isPrepayment: Bool = false
    var prepaymentType: PrepaymentType? = nil

    var amount: Decimal? {
        Decimal(string: amountStr.replacingOccurrences(of: ",", with: "."))
    }
    var isPast: Bool { date <= Date() }
}

// MARK: - Лист добавления / редактирования кредита

struct AddLoanSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Query private var allCurrencies: [Currency]

    let loan: Loan?

    init(loan: Loan? = nil) {
        self.loan = loan
        if let l = loan {
            _name         = State(initialValue: l.name)
            _borrowerName = State(initialValue: l.borrowerName ?? "")
            _amountStr    = State(initialValue: NSDecimalNumber(decimal: l.originalAmount).stringValue)
            _rateStr      = State(initialValue: NSDecimalNumber(decimal: l.interestRate).stringValue)
            _termStr      = State(initialValue: "\(l.termMonths)")
            _paymentStr   = State(initialValue: NSDecimalNumber(decimal: l.monthlyPayment).stringValue)
            _startDate    = State(initialValue: l.startDate)
            _paymentDay   = State(initialValue: l.paymentDay)
            _currency     = State(initialValue: l.currency)
            _iconId       = State(initialValue: l.iconId)
            if let first = l.firstPaymentDate {
                _useFirstPaymentDate = State(initialValue: true)
                _firstPaymentDate    = State(initialValue: first)
            }
            if let fp = l.firstPaymentAmount {
                _firstPaymentStr = State(initialValue: NSDecimalNumber(decimal: fp).stringValue)
            }
        }
    }

    @State private var name: String = ""
    @State private var borrowerName: String = ""
    @State private var amountStr: String = ""
    @State private var rateStr: String = ""
    @State private var termStr: String = ""
    @State private var paymentStr: String = ""
    @State private var startDate: Date = Date()
    @State private var useFirstPaymentDate: Bool = false
    @State private var firstPaymentDate: Date = Date()
    @State private var firstPaymentStr: String = ""
    @State private var paymentDay: Int = 15
    @State private var currency: String = "RUB"

    @State private var showAmountError = false
    @State private var showRateError = false
    @State private var showTermError = false

    @State private var showScheduleEditor = false
    @State private var showIconPicker = false
    @State private var draftEntries: [DraftEntry] = []
    @State private var iconId: String = ""

    private var userCurrencies: [Currency] {
        guard let uid = currentUserId() else { return [] }
        return allCurrencies.filter { $0.userId == uid }
    }
    private var allCurrencyOptions: [CurrencyInfo] { CurrencyInfo.all(custom: userCurrencies) }
    private var selectedCurrencyLabel: String {
        let info = CurrencyInfo.info(for: currency, custom: userCurrencies)
        return "\(info.symbol) \(info.name)"
    }

    private var amount: Decimal? { Decimal(string: amountStr.replacingOccurrences(of: ",", with: ".")) }
    private var rate: Decimal? { Decimal(string: rateStr.replacingOccurrences(of: ",", with: ".")) }
    private var termMonths: Int? { Int(termStr) }

    private var computedPayment: Decimal? {
        guard let a = amount, let r = rate, let t = termMonths, a > 0, r >= 0, t > 0 else { return nil }
        return LoanService.annuityPayment(principal: a, annualRate: r, months: t)
    }

    private var effectivePayment: Decimal? {
        if let manual = Decimal(string: paymentStr.replacingOccurrences(of: ",", with: ".")), !paymentStr.isEmpty {
            return manual
        }
        return computedPayment
    }

    private var firstPaymentOverride: Decimal? {
        guard !firstPaymentStr.isEmpty else { return nil }
        return Decimal(string: firstPaymentStr.replacingOccurrences(of: ",", with: "."))
    }

    private var paymentDayLabel: String {
        paymentDay == 0 ? AppSettings.shared.bundle.localizedString(forKey: "Последнее число", value: "Последнее число", table: nil) : "\(paymentDay)"
    }

    private var isEditing: Bool { loan != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    // MARK: Название
                    VStack(alignment: .leading, spacing: 0) {
                        // Иконка банка
                        HStack(spacing: 12) {
                            BankIconBadge(iconId: iconId, size: 36)
                            Text("Банк")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(BankIcons.info(for: iconId)?.name ?? "По умолчанию")
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .contentShape(Rectangle())
                        .onTapGesture { showIconPicker = true }

                        Divider().padding(.leading, 16)

                        HStack(spacing: 12) {
                            Image(systemName: "building.columns")
                                .foregroundStyle(Color(hex: "E74C3C"))
                                .frame(width: 20)
                            TextField("Название (напр., Ипотека Сбербанк)", text: $name)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)

                        Divider().padding(.leading, 16)

                        HStack(spacing: 12) {
                            Image(systemName: "person")
                                .foregroundStyle(Color(hex: "E74C3C"))
                                .frame(width: 20)
                            TextField("На кого взят кредит (необязательно)", text: $borrowerName)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)
                    }
                    .cardStyle()
                    .padding(.horizontal)
                    .sheet(isPresented: $showIconPicker) {
                        BankIconPickerSheet(selectedId: $iconId)
                    }

                    // MARK: Дисклеймер (только при создании)
                    if !isEditing {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(Color(hex: "E74C3C").opacity(0.7))
                                .font(.subheadline)
                                .padding(.top, 1)
                            Text("Введите параметры из договора. Если первый платёж отличается по сумме или дате — включите «Дата первого платежа» и укажите сумму из банковского графика. Это позволяет рассчитать всё до копейки.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 20)
                    }

                    // MARK: Параметры кредита
                    if isEditing, let loan {
                        // Режим редактирования: сумма, ставка, срок, валюта и дата выдачи — read-only
                        VStack(spacing: 0) {
                            editInfoRow(icon: "rublesign", label: "Сумма кредита",
                                        value: "\(NSDecimalNumber(decimal: loan.originalAmount).intValue) \(CurrencyInfo.symbol(for: loan.currency))")
                            Divider().padding(.leading, 16)
                            editInfoRow(icon: "percent", label: "Ставка",
                                        value: "\(NSDecimalNumber(decimal: loan.interestRate).doubleValue.formatted(.number.precision(.fractionLength(0...2))))% годовых")
                            Divider().padding(.leading, 16)
                            editInfoRow(icon: "calendar.badge.clock", label: "Срок",
                                        value: "\(loan.termMonths) мес.")
                            Divider().padding(.leading, 16)
                            // Ежемесячный платёж — редактируемый
                            HStack(spacing: 12) {
                                Image(systemName: "banknote")
                                    .foregroundStyle(Color(hex: "E74C3C"))
                                    .frame(width: 20)
                                TextField(
                                    "Ежемесячный платёж (\(NSDecimalNumber(decimal: loan.monthlyPayment).intValue) \(CurrencyInfo.symbol(for: loan.currency)))",
                                    text: $paymentStr
                                )
                                .keyboardType(.decimalPad)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 14)
                        }
                        .cardStyle()
                        .padding(.horizontal)

                        Text("Сумма, ставка и срок зафиксированы — их изменение сломало бы расчёт уже совершённых платежей.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)
                    } else {
                        VStack(spacing: 0) {
                            // Сумма
                            HStack(spacing: 12) {
                                Image(systemName: "rublesign")
                                    .foregroundStyle(Color(hex: "E74C3C"))
                                    .frame(width: 20)
                                TextField("Сумма кредита", text: $amountStr)
                                    .keyboardType(.decimalPad)
                                    .foregroundStyle(showAmountError ? .red : .primary)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 14)

                            Divider().padding(.leading, 16)

                            // Ставка
                            HStack(spacing: 12) {
                                Image(systemName: "percent")
                                    .foregroundStyle(Color(hex: "E74C3C"))
                                    .frame(width: 20)
                                TextField("Процентная ставка (% годовых)", text: $rateStr)
                                    .keyboardType(.decimalPad)
                                    .foregroundStyle(showRateError ? .red : .primary)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 14)

                            Divider().padding(.leading, 16)

                            // Срок
                            HStack(spacing: 12) {
                                Image(systemName: "calendar.badge.clock")
                                    .foregroundStyle(Color(hex: "E74C3C"))
                                    .frame(width: 20)
                                TextField("Срок (в месяцах)", text: $termStr)
                                    .keyboardType(.numberPad)
                                    .foregroundStyle(showTermError ? .red : .primary)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 14)

                            Divider().padding(.leading, 16)

                            // Ежемесячный платёж
                            HStack(spacing: 12) {
                                Image(systemName: "banknote")
                                    .foregroundStyle(Color(hex: "E74C3C"))
                                    .frame(width: 20)
                                TextField(
                                    computedPayment.map { "Авторасчёт: \(NSDecimalNumber(decimal: $0).intValue) ₽" } ?? "Ежемесячный платёж",
                                    text: $paymentStr
                                )
                                .keyboardType(.decimalPad)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 14)
                        }
                        .cardStyle()
                        .padding(.horizontal)
                    }

                    // MARK: Даты и расписание
                    VStack(spacing: 0) {
                        // Дата выдачи
                        HStack(spacing: 12) {
                            Image(systemName: "calendar")
                                .foregroundStyle(Color(hex: "E74C3C"))
                                .frame(width: 20)
                            Text("Дата выдачи")
                            Spacer()
                            DatePicker("", selection: $startDate, displayedComponents: [.date])
                                .labelsHidden()
                        }
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .onChange(of: startDate) { _, newStart in
                            if useFirstPaymentDate && firstPaymentDate < newStart {
                                firstPaymentDate = newStart
                            }
                        }

                        Divider().padding(.leading, 16)

                        // Дата первого платежа
                        HStack(spacing: 12) {
                            Image(systemName: "calendar.badge.plus")
                                .foregroundStyle(Color(hex: "E74C3C"))
                                .frame(width: 20)
                            Text("Дата первого платежа")
                            Spacer()
                            Toggle("", isOn: $useFirstPaymentDate)
                                .labelsHidden()
                                .tint(Color(hex: "E74C3C"))
                        }
                        .padding(.horizontal, 16).padding(.vertical, 10)

                        if useFirstPaymentDate {
                            Divider().padding(.leading, 44)
                            HStack(spacing: 12) {
                                Spacer().frame(width: 32)
                                Text("Дата")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                DatePicker("", selection: $firstPaymentDate,
                                           in: startDate...,
                                           displayedComponents: [.date])
                                    .labelsHidden()
                            }
                            .padding(.horizontal, 16).padding(.vertical, 10)

                            Divider().padding(.leading, 44)
                            HStack(spacing: 12) {
                                Spacer().frame(width: 32)
                                TextField(
                                    (effectivePayment.map { "Та же: \(NSDecimalNumber(decimal: $0).intValue)" } ?? "Та же, что ежемесячный"),
                                    text: $firstPaymentStr
                                )
                                .keyboardType(.decimalPad)
                                .foregroundStyle(.secondary)
                                Text("(1-й платёж)")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 10)
                        }

                        Divider().padding(.leading, 16)

                        // Число оплаты
                        HStack(spacing: 12) {
                            Image(systemName: "calendar.badge.checkmark")
                                .foregroundStyle(Color(hex: "E74C3C"))
                                .frame(width: 20)
                            Text("Число оплаты")
                            Spacer()
                            Menu {
                                ForEach(1...28, id: \.self) { day in
                                    Button("\(day)") { paymentDay = day }
                                }
                                Divider()
                                Button("Последнее число") { paymentDay = 0 }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(paymentDayLabel)
                                        .foregroundStyle(Color(hex: "E74C3C"))
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption)
                                        .foregroundStyle(Color(hex: "E74C3C"))
                                }
                            }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 10)

                        if !isEditing {
                            Divider().padding(.leading, 16)

                            // Валюта (только при создании)
                            Menu {
                                ForEach(allCurrencyOptions) { info in
                                    Button { currency = info.code } label: {
                                        Text("\(info.symbol) \(info.name)")
                                    }
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "dollarsign.circle")
                                        .foregroundStyle(Color(hex: "E74C3C"))
                                        .frame(width: 20)
                                    Text("Валюта")
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Text(selectedCurrencyLabel)
                                        .foregroundStyle(.secondary)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 16).padding(.vertical, 14)
                            }
                        }
                    }
                    .cardStyle()
                    .padding(.horizontal)

                    if showAmountError || showRateError || showTermError {
                        Text("Заполните все обязательные поля корректными значениями")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }

                    // MARK: Кнопка редактирования графика (только при редактировании)
                    if isEditing {
                        Button {
                            loadScheduleForEdit()
                        } label: {
                            Label("Редактировать будущие платежи", systemImage: "calendar.badge.clock")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.bordered)
                        .tint(Color(hex: "E74C3C"))
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(AppTheme.Colors.pageBackground)
            .navigationTitle(isEditing ? "Редактировать кредит" : "Новый кредит")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isEditing {
                        Button("Сохранить") { saveEdit() }
                            .fontWeight(.semibold)
                            .foregroundStyle(Color(hex: "E74C3C"))
                    } else {
                        Button("Далее") { proceedToSchedule() }
                            .fontWeight(.semibold)
                            .foregroundStyle(Color(hex: "E74C3C"))
                    }
                }
            }
            .navigationDestination(isPresented: $showScheduleEditor) {
                LoanScheduleEditorView(
                    entries: $draftEntries,
                    currency: isEditing ? (loan?.currency ?? currency) : currency,
                    isEditing: isEditing,
                    onSave: {
                        if isEditing {
                            saveEditSchedule()
                        } else {
                            saveCreate()
                        }
                        dismiss()
                    }
                )
            }
        }
    }

    // MARK: - Helpers

    private func editInfoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color(hex: "E74C3C").opacity(0.5))
                .frame(width: 20)
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }

    // MARK: - Actions

    private func proceedToSchedule() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        showAmountError = amount == nil || (amount ?? 0) <= 0
        showRateError   = rate == nil || (rate ?? -1) < 0
        showTermError   = termMonths == nil || (termMonths ?? 0) <= 0
        guard !showAmountError, !showRateError, !showTermError,
              let a = amount, let r = rate, let t = termMonths else { return }
        let payment = effectivePayment ?? LoanService.annuityPayment(principal: a, annualRate: r, months: t)
        let firstDate: Date? = useFirstPaymentDate ? firstPaymentDate : nil
        let tempLoan = Loan(userId: currentUserId() ?? UUID(), name: name,
                            originalAmount: a, interestRate: r, termMonths: t,
                            startDate: startDate, paymentDay: paymentDay,
                            monthlyPayment: payment, currency: currency,
                            firstPaymentDate: firstDate)
        tempLoan.firstPaymentAmount = useFirstPaymentDate ? firstPaymentOverride : nil
        let svc = LoanService(context: context)
        let schedule = svc.generateSchedule(for: tempLoan, payments: [])
        draftEntries = schedule.filter { !$0.isPrepayment }.map { entry in
            DraftEntry(
                paymentNumber: entry.paymentNumber,
                date: entry.date,
                amountStr: NSDecimalNumber(decimal: entry.totalAmount).stringValue,
                isIncluded: true
            )
        }
        showScheduleEditor = true
    }

    private func saveCreate() {
        guard let a = amount, let r = rate, let t = termMonths else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        let firstDate: Date? = useFirstPaymentDate ? firstPaymentDate : nil
        let paymentOverride: Decimal? = paymentStr.isEmpty ? nil : effectivePayment
        let entries = draftEntries.filter { $0.isIncluded }.compactMap {
            e -> (date: Date, amount: Decimal, isPrepayment: Bool, prepaymentType: PrepaymentType?)? in
            guard let amt = e.amount, amt > 0 else { return nil }
            return (date: e.date, amount: amt,
                    isPrepayment: e.isPrepayment,
                    prepaymentType: e.isPrepayment ? e.prepaymentType : nil)
        }
        let trimmedBorrower = borrowerName.trimmingCharacters(in: .whitespaces)
        LoanService(context: context).addLoanWithSchedule(
            name: trimmedName, originalAmount: a, interestRate: r,
            termMonths: t, startDate: startDate, paymentDay: paymentDay,
            currency: currency, firstPaymentDate: firstDate,
            firstPaymentAmount: useFirstPaymentDate ? firstPaymentOverride : nil,
            monthlyPaymentOverride: paymentOverride,
            scheduledEntries: entries,
            borrowerName: trimmedBorrower.isEmpty ? nil : trimmedBorrower,
            iconId: iconId
        )
    }

    private func saveEdit() {
        guard let loan else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        let firstDate: Date? = useFirstPaymentDate ? firstPaymentDate : nil
        let paymentOverride: Decimal? = paymentStr.isEmpty ? nil : effectivePayment
        let trimmedBorrower = borrowerName.trimmingCharacters(in: .whitespaces)
        // Ставку и срок не меняем — они влияют на весь расчёт графика, включая прошлые платежи
        LoanService(context: context).updateLoan(loan, name: trimmedName,
                                                  interestRate: loan.interestRate,
                                                  termMonths: loan.termMonths,
                                                  paymentDay: paymentDay,
                                                  firstPaymentDate: firstDate,
                                                  firstPaymentAmount: useFirstPaymentDate ? firstPaymentOverride : nil,
                                                  monthlyPaymentOverride: paymentOverride,
                                                  borrowerName: trimmedBorrower.isEmpty ? nil : trimmedBorrower,
                                                  iconId: iconId)
        dismiss()
    }

    private func loadScheduleForEdit() {
        guard let loan else { return }
        let allPayments = (try? context.fetch(FetchDescriptor<LoanPayment>())) ?? []
        let loanPayments = allPayments.filter { $0.loanId == loan.id }
        let today = Date()

        let futureRegular = loanPayments
            .filter { !$0.isPrepayment && $0.date > today }
            .sorted { $0.date < $1.date }

        if futureRegular.isEmpty {
            // Платежей в БД нет — генерируем из текущего расчёта
            let svc = LoanService(context: context)
            let schedule = svc.generateSchedule(for: loan, payments: loanPayments)
            draftEntries = schedule
                .filter { !$0.isPaid && !$0.isPrepayment }
                .enumerated()
                .map { idx, entry in
                    DraftEntry(
                        paymentNumber: idx + 1,
                        date: entry.date,
                        amountStr: NSDecimalNumber(decimal: entry.totalAmount).stringValue,
                        isIncluded: true,
                        isManuallyAdded: true,
                        isScheduled: true
                    )
                }
        } else {
            draftEntries = futureRegular.enumerated().map { idx, p in
                DraftEntry(
                    paymentNumber: idx + 1,
                    date: p.date,
                    amountStr: NSDecimalNumber(decimal: p.totalAmount).stringValue,
                    isIncluded: true,
                    isManuallyAdded: true,
                    isScheduled: true
                )
            }
        }
        showScheduleEditor = true
    }

    private func saveEditSchedule() {
        guard let loan else { return }
        let allPayments = (try? context.fetch(FetchDescriptor<LoanPayment>())) ?? []
        let loanPayments = allPayments.filter { $0.loanId == loan.id }
        let entries = draftEntries.filter { $0.isIncluded }.compactMap {
            e -> (date: Date, amount: Decimal, isPrepayment: Bool, prepaymentType: PrepaymentType?)? in
            guard let amt = e.amount, amt > 0 else { return nil }
            return (date: e.date, amount: amt,
                    isPrepayment: e.isPrepayment,
                    prepaymentType: e.isPrepayment ? e.prepaymentType : nil)
        }
        LoanService(context: context).updateSchedule(for: loan, allPayments: loanPayments, newEntries: entries)
    }
}

// MARK: - Редактор графика платежей

struct LoanScheduleEditorView: View {
    @Binding var entries: [DraftEntry]
    let currency: String
    var isEditing: Bool = false
    let onSave: () -> Void
    @Environment(\.locale) private var locale

    // Дебаунс для сортировки: сортируем только спустя 0.35с после последнего изменения даты
    @State private var lastDateChangeTime: Date = .distantPast
    // ID записи, к которой надо прокрутить после сортировки/вставки
    @State private var scrollToId: UUID? = nil

    private var currencySymbol: String { CurrencyInfo.symbol(for: currency) }
    private var includedCount: Int { entries.filter { $0.isIncluded }.count }
    private var pastCount: Int { entries.filter { $0.isIncluded && $0.isPast }.count }

    var body: some View {
        ScrollViewReader { proxy in
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(isEditing
                             ? "Запланированные будущие платежи по кредиту."
                             : "Предварительный расчёт платежей по кредиту.")
                            .font(.subheadline.bold())
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Переключатель — включить/отключить платёж", systemImage: "togglepower")
                            Label("Сумма и дата редактируются под условия банка", systemImage: "pencil")
                            Label("Кнопка «+» внизу — добавить досрочный или доп. платёж", systemImage: "plus.circle")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        if !isEditing && pastCount > 0 {
                            Label("\(pastCount) прош. платеж\(pastCount == 1 ? "" : "а") — отметятся выполненными", systemImage: "checkmark.circle")
                                .font(.caption)
                                .foregroundStyle(AppTheme.Colors.income)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Платежи (\(includedCount) из \(entries.count))") {
                    // ForEach со стабильными UUID-идентификаторами — строки не прыгают при сортировке
                    ForEach($entries) { $entry in
                        let e = $entry.wrappedValue
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(dotColor(for: e))
                                    .frame(width: 8, height: 8)
                                    .opacity(e.isIncluded ? 1 : 0.25)

                                VStack(alignment: .leading, spacing: 2) {
                                    if e.isManuallyAdded {
                                        DatePicker("", selection: $entry.date, displayedComponents: [.date])
                                            .labelsHidden()
                                            .onChange(of: e.date) { _, _ in
                                                // Сортируем только после закрытия пикера (дебаунс 350ms)
                                                scheduleSort(for: e.id)
                                            }
                                    } else {
                                        Text(e.date, format: .dateTime.day().month(.wide).year().locale(locale))
                                            .font(.subheadline)
                                            .foregroundStyle(e.isIncluded ? .primary : .secondary)
                                    }
                                    if e.isPast && e.isIncluded && !e.isPrepayment {
                                        Text("Выполнен").font(.caption2).foregroundStyle(AppTheme.Colors.income)
                                    }
                                    if e.isPrepayment && e.isIncluded {
                                        Text("Досрочный")
                                            .font(.caption2.bold())
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 6).padding(.vertical, 2)
                                            .background(Color(hex: "E74C3C"))
                                            .clipShape(Capsule())
                                    }
                                }

                                Spacer()

                                if e.isIncluded {
                                    HStack(spacing: 2) {
                                        TextField("", text: $entry.amountStr)
                                            .keyboardType(.decimalPad)
                                            .multilineTextAlignment(.trailing)
                                            .frame(width: 80)
                                            .foregroundStyle(.primary)
                                        Text(currencySymbol).font(.caption.bold()).foregroundStyle(.secondary)
                                    }
                                }

                                Toggle("", isOn: $entry.isIncluded).labelsHidden().tint(AppTheme.Colors.accent)
                            }

                            if e.isManuallyAdded && !e.isScheduled && e.isIncluded {
                                HStack(spacing: 8) {
                                    Spacer().frame(width: 16)
                                    Toggle(isOn: Binding(
                                        get: { e.isPrepayment },
                                        set: { on in
                                            $entry.wrappedValue.isPrepayment = on
                                            if on && $entry.wrappedValue.prepaymentType == nil {
                                                $entry.wrappedValue.prepaymentType = .reduceTerm
                                            } else if !on {
                                                $entry.wrappedValue.prepaymentType = nil
                                            }
                                        }
                                    )) {
                                        Text("Досрочный платёж").font(.caption).foregroundStyle(.secondary)
                                    }
                                    .tint(Color(hex: "E74C3C"))
                                }

                                if e.isPrepayment {
                                    HStack(spacing: 8) {
                                        Spacer().frame(width: 16)
                                        Picker("", selection: Binding(
                                            get: { e.prepaymentType ?? .reduceTerm },
                                            set: { $entry.wrappedValue.prepaymentType = $0 }
                                        )) {
                                            Text("Уменьшить срок").tag(PrepaymentType.reduceTerm)
                                            Text("Уменьшить платёж").tag(PrepaymentType.reducePayment)
                                        }
                                        .pickerStyle(.segmented)
                                    }
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }
                        }
                        .padding(.vertical, 2)
                        .animation(.spring(response: 0.25), value: e.isPrepayment)
                        .id(e.id)  // нужен для ScrollViewReader.scrollTo
                    }

                    Button {
                        addManualEntry()
                    } label: {
                        Label("Добавить платёж", systemImage: "plus.circle.fill")
                            .foregroundStyle(Color(hex: "E74C3C"))
                    }
                }
            }
            .onChange(of: scrollToId) { _, newId in
                guard let id = newId else { return }
                // Небольшая задержка чтобы List успел обновить layout после сортировки/вставки
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                    scrollToId = nil
                }
            }
        }
        .navigationTitle("График платежей")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                Button(action: onSave) {
                    Label(isEditing ? "Обновить график" : "Создать кредит", systemImage: "checkmark.circle.fill")
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
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .background(Color(.secondarySystemGroupedBackground))
        }
    }

    // Откладывает сортировку на 350ms после последнего изменения даты.
    // Если пользователь изменил дату в пикере, он успевает закрыть пикер до того как строка переместится.
    private func scheduleSort(for entryId: UUID) {
        let changeTime = Date()
        lastDateChangeTime = changeTime
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            guard lastDateChangeTime == changeTime else { return }
            withAnimation(.spring(response: 0.35)) {
                entries.sort { $0.date < $1.date }
            }
            scrollToId = entryId
        }
    }

    private func dotColor(for entry: DraftEntry) -> Color {
        if entry.isPrepayment { return Color(hex: "E74C3C") }
        return entry.isPast ? AppTheme.Colors.income : AppTheme.Colors.accent
    }

    private func addManualEntry() {
        let lastDate = entries.last?.date ?? Date()
        let nextDate = Calendar.current.date(byAdding: .month, value: 1, to: lastDate) ?? lastDate
        // Берём сумму последнего платежа как дефолт для нового
        let lastAmountStr: String = {
            guard let last = entries.last, let amt = last.amount else { return "" }
            return "\(NSDecimalNumber(decimal: amt).intValue)"
        }()
        let nextNum = (entries.map { $0.paymentNumber }.max() ?? 0) + 1
        let newEntry = DraftEntry(
            paymentNumber: nextNum,
            date: nextDate,
            amountStr: lastAmountStr,
            isIncluded: true,
            isManuallyAdded: true
        )
        let insertIdx = entries.firstIndex(where: { $0.date > nextDate }) ?? entries.endIndex
        entries.insert(newEntry, at: insertIdx)
        // Даём List один цикл на обновление перед прокруткой
        DispatchQueue.main.async {
            scrollToId = newEntry.id
        }
    }
}
