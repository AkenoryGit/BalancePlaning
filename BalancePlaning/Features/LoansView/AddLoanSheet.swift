//
//  AddLoanSheet.swift
//  BalancePlaning
//

import SwiftUI
import SwiftData

struct AddLoanSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var allCurrencies: [Currency]

    let loan: Loan?

    init(loan: Loan? = nil) {
        self.loan = loan
        if let l = loan {
            _name = State(initialValue: l.name)
            _amountStr  = State(initialValue: NSDecimalNumber(decimal: l.originalAmount).stringValue)
            _rateStr    = State(initialValue: NSDecimalNumber(decimal: l.interestRate).stringValue)
            _termStr    = State(initialValue: "\(l.termMonths)")
            _paymentStr = State(initialValue: NSDecimalNumber(decimal: l.monthlyPayment).stringValue)
            _startDate  = State(initialValue: l.startDate)
            _paymentDay = State(initialValue: l.paymentDay)
            _currency   = State(initialValue: l.currency)
            if let first = l.firstPaymentDate {
                _useFirstPaymentDate = State(initialValue: true)
                _firstPaymentDate    = State(initialValue: first)
            }
        }
    }

    @State private var name: String = ""
    @State private var amountStr: String = ""
    @State private var rateStr: String = ""
    @State private var termStr: String = ""
    @State private var paymentStr: String = ""        // переопределение платежа
    @State private var startDate: Date = Date()
    @State private var useFirstPaymentDate: Bool = false
    @State private var firstPaymentDate: Date = Date()
    @State private var paymentDay: Int = 15
    @State private var currency: String = "RUB"

    @State private var showAmountError = false
    @State private var showRateError = false
    @State private var showTermError = false

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
        guard let a = amount, let r = rate, let t = termMonths, a > 0, r > 0, t > 0 else { return nil }
        return LoanService.annuityPayment(principal: a, annualRate: r, months: t)
    }

    /// Финальный платёж: введённый вручную или авторасчёт
    private var effectivePayment: Decimal? {
        if let manual = Decimal(string: paymentStr.replacingOccurrences(of: ",", with: ".")), !paymentStr.isEmpty {
            return manual
        }
        return computedPayment
    }

    private var paymentDayLabel: String {
        paymentDay == 0 ? "Последнее число" : "\(paymentDay)"
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

                        // Ежемесячный платёж (авто или ручной)
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
                                .environment(\.locale, Locale(identifier: "ru_RU"))
                        }
                        .padding(.horizontal, 16).padding(.vertical, 10)

                        Divider().padding(.leading, 16)

                        // Дата первого платежа (опционально)
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
                                    .environment(\.locale, Locale(identifier: "ru_RU"))
                            }
                            .padding(.horizontal, 16).padding(.vertical, 10)
                        }

                        Divider().padding(.leading, 16)

                        // Число оплаты (1-28 + последнее число)
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
                    Button(isEditing ? "Сохранить" : "Добавить") { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color(hex: "E74C3C"))
                }
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let firstDate: Date? = useFirstPaymentDate ? firstPaymentDate : nil
        let svc = LoanService(context: context)

        if let loan = loan {
            // Редактирование: amount менять нельзя, валидируем только rate и term
            showRateError  = rate == nil || (rate ?? 0) <= 0
            showTermError  = termMonths == nil || (termMonths ?? 0) <= 0
            guard !showRateError, !showTermError,
                  let r = rate, let t = termMonths else { return }
            let paymentOverride: Decimal? = paymentStr.isEmpty ? nil : effectivePayment
            svc.updateLoan(loan, name: trimmedName, interestRate: r, termMonths: t,
                           paymentDay: paymentDay, firstPaymentDate: firstDate,
                           monthlyPaymentOverride: paymentOverride)
        } else {
            // Создание: валидируем все поля включая amount
            showAmountError = amount == nil || (amount ?? 0) <= 0
            showRateError   = rate == nil || (rate ?? 0) <= 0
            showTermError   = termMonths == nil || (termMonths ?? 0) <= 0
            guard !showAmountError, !showRateError, !showTermError,
                  let a = amount, let r = rate, let t = termMonths else { return }
            let paymentOverride: Decimal? = paymentStr.isEmpty ? nil : effectivePayment
            svc.addLoan(name: trimmedName, originalAmount: a, interestRate: r,
                        termMonths: t, startDate: startDate, paymentDay: paymentDay,
                        currency: currency, firstPaymentDate: firstDate,
                        monthlyPaymentOverride: paymentOverride)
        }
        dismiss()
    }
}
