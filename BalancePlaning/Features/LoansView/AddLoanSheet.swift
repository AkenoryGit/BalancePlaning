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
    let date: Date
    var amountStr: String
    var isIncluded: Bool = true

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
            if let first = l.firstPaymentDate {
                _useFirstPaymentDate = State(initialValue: true)
                _firstPaymentDate    = State(initialValue: first)
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
    @State private var paymentDay: Int = 15
    @State private var currency: String = "RUB"

    @State private var showAmountError = false
    @State private var showRateError = false
    @State private var showTermError = false

    @State private var showScheduleEditor = false
    @State private var draftEntries: [DraftEntry] = []

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

                    // MARK: Параметры кредита
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
                                DatePicker("", selection: $firstPaymentDate, displayedComponents: [.date])
                                    .labelsHidden()
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

                        Divider().padding(.leading, 16)

                        // Валюта
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
                    .cardStyle()
                    .padding(.horizontal)

                    if showAmountError || showRateError || showTermError {
                        Text("Заполните все обязательные поля корректными значениями")
                            .font(.caption)
                            .foregroundStyle(.red)
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
                    currency: currency,
                    onSave: {
                        saveCreate()
                        dismiss()
                    }
                )
            }
        }
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
        let entries = draftEntries.filter { $0.isIncluded }.compactMap { e -> (date: Date, amount: Decimal)? in
            guard let amt = e.amount, amt > 0 else { return nil }
            return (date: e.date, amount: amt)
        }
        let trimmedBorrower = borrowerName.trimmingCharacters(in: .whitespaces)
        LoanService(context: context).addLoanWithSchedule(
            name: trimmedName, originalAmount: a, interestRate: r,
            termMonths: t, startDate: startDate, paymentDay: paymentDay,
            currency: currency, firstPaymentDate: firstDate,
            monthlyPaymentOverride: paymentOverride,
            scheduledEntries: entries,
            borrowerName: trimmedBorrower.isEmpty ? nil : trimmedBorrower
        )
    }

    private func saveEdit() {
        guard let loan else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        showRateError  = rate == nil || (rate ?? -1) < 0
        showTermError  = termMonths == nil || (termMonths ?? 0) <= 0
        guard !showRateError, !showTermError,
              let r = rate, let t = termMonths else { return }
        let firstDate: Date? = useFirstPaymentDate ? firstPaymentDate : nil
        let paymentOverride: Decimal? = paymentStr.isEmpty ? nil : effectivePayment
        let trimmedBorrower = borrowerName.trimmingCharacters(in: .whitespaces)
        LoanService(context: context).updateLoan(loan, name: trimmedName, interestRate: r,
                                                  termMonths: t, paymentDay: paymentDay,
                                                  firstPaymentDate: firstDate,
                                                  monthlyPaymentOverride: paymentOverride,
                                                  borrowerName: trimmedBorrower.isEmpty ? nil : trimmedBorrower)
        dismiss()
    }
}

// MARK: - Редактор графика платежей

struct LoanScheduleEditorView: View {
    @Binding var entries: [DraftEntry]
    let currency: String
    let onSave: () -> Void
    @Environment(\.locale) private var locale

    private var currencySymbol: String { CurrencyInfo.symbol(for: currency) }
    private var includedCount: Int { entries.filter { $0.isIncluded }.count }
    private var pastCount: Int { entries.filter { $0.isIncluded && $0.isPast }.count }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Все включённые платежи создадутся как операции.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if pastCount > 0 {
                        Label("\(pastCount) прош. платеж\(pastCount == 1 ? "" : "а") — отметятся выполненными", systemImage: "checkmark.circle")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.income)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Платежи (\(includedCount) из \(entries.count))") {
                ForEach(entries.indices, id: \.self) { i in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(entries[i].isPast ? AppTheme.Colors.income : AppTheme.Colors.accent)
                            .frame(width: 8, height: 8)
                            .opacity(entries[i].isIncluded ? 1 : 0.25)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(entries[i].date, format: .dateTime
                                .day().month(.wide).year().locale(locale))
                                .font(.subheadline)
                                .foregroundStyle(entries[i].isIncluded ? .primary : .secondary)
                            if entries[i].isPast && entries[i].isIncluded {
                                Text("Выполнен")
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.Colors.income)
                            }
                        }

                        Spacer()

                        if entries[i].isIncluded {
                            HStack(spacing: 2) {
                                TextField("", text: $entries[i].amountStr)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 80)
                                    .foregroundStyle(.primary)
                                Text(currencySymbol)
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Toggle("", isOn: $entries[i].isIncluded)
                            .labelsHidden()
                            .tint(AppTheme.Colors.accent)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("График платежей")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                Button(action: onSave) {
                    Label("Создать кредит", systemImage: "checkmark.circle.fill")
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
}
