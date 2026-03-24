//
//  TransactionDetailView.swift
//  BalancePlaning
//

import SwiftUI
import SwiftData

// MARK: - Детали транзакции

struct TransactionDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.locale) private var locale
    let transaction: Transaction
    @Binding var selectedTransaction: Transaction?

    @Query private var allLoans: [Loan]

    @State private var showEdit: Bool = false
    @State private var showDeleteAlert: Bool = false
    @State private var showConfirmDeleteAlert: Bool = false
    @State private var editWasSaved: Bool = false
    @State private var pendingAction: (() -> Void)?

    private var loanBorrowerName: String? {
        guard let lid = transaction.loanId else { return nil }
        return allLoans.first { $0.id == lid }?.borrowerName
    }

    private var detailCurrencySymbol: String {
        switch transaction.type {
        case .income:      return CurrencyInfo.symbol(for: transaction.toAccount?.currency ?? "RUB")
        case .expense:     return CurrencyInfo.symbol(for: transaction.fromAccount?.currency ?? "RUB")
        case .transaction: return CurrencyInfo.symbol(for: transaction.fromAccount?.currency ?? "RUB")
        case .correction:  return CurrencyInfo.symbol(for: (transaction.fromAccount ?? transaction.toAccount)?.currency ?? "RUB")
        }
    }

    private var title: String {
        let bundle = AppSettings.shared.bundle
        if transaction.loanId != nil {
            let note = transaction.note
            let prepayPrefix = "Досрочное погашение: "
            let regularPrefix = "Платёж по кредиту: "
            if note.hasPrefix(prepayPrefix) {
                let loanName = String(note.dropFirst(prepayPrefix.count))
                let localPrefix = bundle.localizedString(forKey: "Досрочное погашение", value: "Досрочное погашение", table: nil)
                return "\(localPrefix): \(loanName)"
            } else if note.hasPrefix(regularPrefix) {
                let loanName = String(note.dropFirst(regularPrefix.count))
                let localPrefix = bundle.localizedString(forKey: "Платёж по кредиту", value: "Платёж по кредиту", table: nil)
                return "\(localPrefix): \(loanName)"
            }
            return note.isEmpty ? bundle.localizedString(forKey: "Платёж по кредиту", value: "Платёж по кредиту", table: nil) : note
        }
        switch transaction.type {
        case .income:      return transaction.fromCategory?.name ?? bundle.localizedString(forKey: "Пополнение", value: "Пополнение", table: nil)
        case .expense:     return transaction.toCategory?.name ?? bundle.localizedString(forKey: "Расход", value: "Расход", table: nil)
        case .transaction: return bundle.localizedString(forKey: "Перевод", value: "Перевод", table: nil)
        case .correction:  return bundle.localizedString(forKey: "Корректировка", value: "Корректировка", table: nil)
        }
    }

    var body: some View {
        VStack(spacing: 0) {

            // Шапка
            VStack(spacing: 8) {
                Image(systemName: transaction.type.icon)
                    .font(.system(size: 48))
                    .foregroundStyle(transaction.type.color)
                    .padding(.top, 32)

                Text(title)
                    .font(.title2.bold())

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    if !transaction.type.amountPrefix.isEmpty {
                        Text(transaction.type.amountPrefix)
                            .font(.system(size: 28, weight: .bold))
                    }
                    Text(transaction.amount, format: .number.precision(.fractionLength(0...2)))
                        .font(.system(size: 32, weight: .bold))
                    Text(detailCurrencySymbol)
                        .font(.title2.bold())
                }
                .foregroundStyle(transaction.type.color)

                Text(transaction.date, format: .dateTime
                    .day().month(.wide).year()
                    .hour().minute()
                    .locale(locale)
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 20)
            }

            Divider()

            // Строки с деталями
            VStack(spacing: 0) {
                if transaction.type == .income {
                    DetailRow(label: "На счёт",    value: transaction.toAccount?.name ?? "—")
                    DetailRow(label: "Категория",  value: transaction.fromCategory?.name ?? "—")
                } else if transaction.type == .expense {
                    DetailRow(label: "Со счёта",   value: transaction.fromAccount?.name ?? "—")
                    DetailRow(label: "Категория",  value: transaction.toCategory?.name ?? "—")
                } else if transaction.type == .correction {
                    let accountName = transaction.toAccount?.name ?? transaction.fromAccount?.name ?? "—"
                    let direction   = transaction.toAccount != nil ? "Пополнение" : "Списание"
                    DetailRow(label: "Счёт",       value: accountName)
                    DetailRow(label: "Направление", value: direction)
                } else {
                    DetailRow(label: "Со счёта",   value: transaction.fromAccount?.name ?? "—")
                    DetailRow(label: "На счёт",    value: transaction.toAccount?.name ?? "—")
                    if let toAmt = transaction.toAmount {
                        let sym = CurrencyInfo.symbol(for: transaction.toAccount?.currency ?? "RUB")
                        let formatted: String = {
                            let ns = NSDecimalNumber(decimal: toAmt)
                            let fmt = NumberFormatter()
                            fmt.minimumFractionDigits = 0; fmt.maximumFractionDigits = 2
                            return fmt.string(from: ns) ?? ns.stringValue
                        }()
                        DetailRow(label: "Зачислено", value: "\(formatted) \(sym)")
                    }
                }
                // Для кредитов и корректировок показываем поле comment, для остальных — note
                if transaction.loanId != nil || transaction.type == .correction {
                    if !transaction.comment.isEmpty {
                        DetailRow(label: "Комментарий", value: transaction.comment)
                    }
                    if let borrower = loanBorrowerName {
                        DetailRow(label: "На кого взят", value: borrower)
                    }
                } else if !transaction.note.isEmpty {
                    DetailRow(label: "Заметка", value: transaction.note)
                }
                if transaction.recurringGroupId != nil {
                    DetailRow(label: "Тип", value: "Повторяющаяся")
                }
            }
            .padding(.horizontal)

            Spacer()

            // Кнопки
            VStack(spacing: 12) {
                if transaction.type != .correction {
                    Button {
                        editWasSaved = false
                        showEdit = true
                    } label: {
                        Label("Редактировать", systemImage: "pencil")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.Colors.accent)
                }

                Button(role: .destructive) {
                    if transaction.recurringGroupId != nil {
                        showDeleteAlert = true
                    } else {
                        showConfirmDeleteAlert = true
                    }
                } label: {
                    Label("Удалить операцию", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .sheet(isPresented: $showEdit) {
            if transaction.loanId != nil {
                EditLoanPaymentSheet(transaction: transaction)
            } else {
                EditTransactionView(
                    isRootPresented: $showEdit,
                    transaction: transaction,
                    onSaved: { action in
                        pendingAction = action
                        editWasSaved = true
                    }
                )
            }
        }
        .onChange(of: showEdit) { _, isShowing in
            if !isShowing && editWasSaved {
                selectedTransaction = nil
            }
        }
        .alert("Удалить операцию?", isPresented: $showConfirmDeleteAlert) {
            Button("Удалить", role: .destructive) {
                let service = TransactionService(context: context)
                pendingAction = { service.deleteTransaction(transaction) }
                selectedTransaction = nil
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Операция удалится безвозвратно")
        }
        .alert("Удалить повторяющуюся операцию?", isPresented: $showDeleteAlert) {
            Button("Только эту", role: .destructive) {
                let service = TransactionService(context: context)
                pendingAction = { service.deleteTransaction(transaction) }
                selectedTransaction = nil
            }
            Button("Все последующие", role: .destructive) {
                guard let groupId = transaction.recurringGroupId else { return }
                let capturedDate = transaction.date
                let service = TransactionService(context: context)
                pendingAction = { service.deleteFollowingTransactions(groupId: groupId, from: capturedDate) }
                selectedTransaction = nil
            }
            Button("Отмена", role: .cancel) {}
        }
        .onDisappear {
            pendingAction?()
            pendingAction = nil
        }
    }
}

// MARK: - Строка деталей

struct DetailRow: View {
    let label: LocalizedStringKey
    let value: String

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .fontWeight(.medium)
            }
            .padding(.vertical, 13)
            Divider()
        }
    }
}
