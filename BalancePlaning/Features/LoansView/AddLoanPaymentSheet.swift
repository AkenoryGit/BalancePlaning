//
//  AddLoanPaymentSheet.swift
//  BalancePlaning
//

import SwiftUI
import SwiftData

struct AddLoanPaymentSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let loan: Loan

    @Query private var allPayments: [LoanPayment]
    @Query private var allAccounts: [Account]

    @State private var isPrepayment = false
    @State private var prepaymentType: PrepaymentType = .reduceTerm
    @State private var amountStr: String = ""
    @State private var paymentDate: Date = Date()
    @State private var selectedAccountId: UUID? = nil
    @State private var comment: String = ""
    @State private var showAmountError = false

    private var service: LoanService { LoanService(context: context) }

    private var userAccounts: [Account] {
        guard let uid = currentUserId() else { return [] }
        return allAccounts.filter { $0.userId == uid }
    }

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
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

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
                                .font(.caption)
                                .foregroundStyle(.red)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)
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
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .padding(.horizontal, 16).padding(.vertical, 14)
                        }
                        .cardStyle()
                        .padding(.horizontal)
                    }

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
        }
        .onAppear {
            if !isPrepayment {
                let d = defaultAmount
                let dbl = LoanService.toDouble(d)
                if dbl > 0 {
                    amountStr = "\(Int(dbl))"
                }
            }
        }
    }

    private func prepaymentPreview(amount: Decimal) -> some View {
        let tempPayments = Array(allPayments) + [LoanPayment(
            loanId: loan.id,
            userId: currentUserId() ?? UUID(),
            date: paymentDate,
            totalAmount: amount,
            isPrepayment: true,
            prepaymentType: prepaymentType
        )]
        let beforeRemaining = service.remainingPrincipal(for: loan, payments: Array(allPayments))
        let afterRemaining  = service.remainingPrincipal(for: loan, payments: tempPayments)
        let beforeMonths    = service.remainingMonths(for: loan, payments: Array(allPayments))
        let afterMonths     = service.remainingMonths(for: loan, payments: tempPayments)
        let beforeMonthly   = service.currentMonthlyPayment(for: loan, payments: Array(allPayments))
        let afterMonthly    = service.currentMonthlyPayment(for: loan, payments: tempPayments)

        return VStack(alignment: .leading, spacing: 0) {
            Text("Предварительный расчёт")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 12)

            Divider().padding(.horizontal, 16).padding(.top, 8)

            HStack {
                previewColumn(title: "Долг до", value: "\(beforeRemaining.formatted(.number.precision(.fractionLength(0...0)))) \(CurrencyInfo.symbol(for: loan.currency))")
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                previewColumn(title: "Долг после", value: "\(afterRemaining.formatted(.number.precision(.fractionLength(0...0)))) \(CurrencyInfo.symbol(for: loan.currency))", highlight: true)
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
                    previewColumn(title: "Платёж до", value: "\(beforeMonthly.formatted(.number.precision(.fractionLength(0...0)))) \(CurrencyInfo.symbol(for: loan.currency))")
                    Image(systemName: "arrow.right").foregroundStyle(.secondary)
                    previewColumn(title: "Платёж после", value: "\(afterMonthly.formatted(.number.precision(.fractionLength(0...0)))) \(CurrencyInfo.symbol(for: loan.currency))", highlight: true)
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
            showAmountError = true
            return
        } else {
            finalAmount = defaultAmount
        }
        guard finalAmount > 0 else { showAmountError = true; return }

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
        dismiss()
    }
}
