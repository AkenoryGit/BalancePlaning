//
//  AddTransactionView.swift
//  BalancePlaning
//

import SwiftUI
import SwiftData

struct AddTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query private var allUserAccounts: [Account]
    @Query private var allCurrencies: [Currency]
    @Query private var allGroups: [AccountGroup]

    @Binding var isRootPresented: Bool

    @State var fromAccount: Account?
    @State var toAccount: Account?
    @State var amount: String = ""
    @State var toAmount: String = ""
    @State var date: Date = Calendar.current.startOfDay(for: Date())
    @State var endDate: Date = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .year, value: 1, to: Date())!)
    @State var recurringOperation: Bool = false
    @State var interval: RecurringInterval? = .monthly
    @State var intervalDays: String = "2"
    @State var priority: TransactionPriority = .normal
    @State var note: String = ""

    var editingTransaction: Transaction? = nil
    var onSaved: (@escaping () -> Void) -> Void = { _ in }
    var transactionService: TransactionService

    @State private var didAttemptSave = false
    @State private var showRecurringAlert = false
    @State private var pendingFrom: Account?
    @State private var pendingTo: Account?
    @State private var pendingAmount: Decimal = 0
    @State private var pendingToAmount: Decimal? = nil

    private var accountService: AccountService { AccountService(context: context) }

    private var userAccounts: [Account] {
        guard let userId = currentUserId() else { return [] }
        return allUserAccounts.filter { $0.userId == userId }
    }

    private var userCurrencies: [Currency] {
        guard let userId = currentUserId() else { return [] }
        return allCurrencies.filter { $0.userId == userId }
    }
    private var userGroups: [AccountGroup] {
        guard let userId = currentUserId() else { return [] }
        return allGroups.filter { $0.userId == userId }
    }
    private func accountLabel(_ acc: Account) -> String {
        if let gid = acc.groupId, let g = userGroups.first(where: { $0.id == gid }) {
            return "\(g.name) / \(acc.name)"
        }
        return acc.name
    }

    private var isCrossCurrency: Bool {
        guard let f = fromAccount, let t = toAccount else { return false }
        return f.currency != t.currency
    }

    private var fromSymbol: String { CurrencyInfo.symbol(for: fromAccount?.currency ?? "RUB", custom: userCurrencies) }
    private var toSymbol:   String { CurrencyInfo.symbol(for: toAccount?.currency   ?? "RUB", custom: userCurrencies) }

    private var amountDecimal: Decimal? {
        let s = amount.replacingOccurrences(of: ",", with: ".")
        guard let d = Decimal(string: s), d > 0 else { return nil }
        return d
    }
    private var toAmountDecimal: Decimal? {
        guard isCrossCurrency else { return nil }
        let s = toAmount.replacingOccurrences(of: ",", with: ".")
        guard let d = Decimal(string: s), d > 0 else { return nil }
        return d
    }
    private var amountValid:   Bool { amountDecimal != nil }
    private var toAmountValid: Bool { !isCrossCurrency || toAmountDecimal != nil }
    private var fromValid:     Bool { fromAccount != nil }
    private var toValid:       Bool { toAccount != nil }
    private var sameAccount:   Bool {
        if let f = fromAccount, let t = toAccount { return f.id == t.id }
        return false
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    AmountInputCard(
                        icon: "arrow.left.arrow.right.circle.fill",
                        typeLabel: "Перевод",
                        color: AppTheme.Colors.transfer,
                        amount: $amount,
                        showError: didAttemptSave && !amountValid
                    )

                    if isCrossCurrency {
                        AmountInputCard(
                            icon: "arrow.right.circle.fill",
                            typeLabel: "Получает",
                            color: AppTheme.Colors.income,
                            amount: $toAmount,
                            showError: didAttemptSave && !toAmountValid
                        )
                    }

                    fieldsCard

                    ScheduleSection(
                        date: $date, endDate: $endDate,
                        isRecurring: $recurringOperation,
                        interval: $interval, intervalDays: $intervalDays
                    )

                    PrioritySection(priority: $priority)
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .dismissKeyboardOnDrag()
            .background(AppTheme.Colors.pageBackground)
            .navigationTitle(editingTransaction == nil ? "Новый перевод" : "Изменить перевод")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }.foregroundStyle(.secondary)
                }
            }
            .safeAreaInset(edge: .bottom) {
                TransactionSaveBar(
                    label: editingTransaction == nil ? "Добавить перевод" : "Сохранить изменения",
                    color: AppTheme.Colors.transfer,
                    action: handleSave
                )
            }
            .alert("Изменить повторяющуюся операцию?", isPresented: $showRecurringAlert) {
                Button("Только эту") { saveOnlyThis() }
                Button("Все последующие") { saveFollowing() }
                Button("Отмена", role: .cancel) {}
            }
        }
    }

    private var fieldsCard: some View {
        VStack(spacing: 0) {
            pickerRow(
                icon: "arrow.up.circle.fill", iconColor: AppTheme.Colors.expense,
                label: "Списать со счёта", value: fromAccount.map { accountLabel($0) },
                hasError: didAttemptSave && !fromValid, errorText: "Выберите счёт списания"
            ) {
                ForEach(userAccounts) { acc in
                    Button {
                        fromAccount = acc
                    } label: {
                        let sym = CurrencyInfo.symbol(for: acc.currency, custom: userCurrencies)
                        Text("\(acc.name)  \(accountService.currentBalance(for: acc), format: .number.precision(.fractionLength(0...2))) \(sym)")
                    }
                }
            }

            Divider().padding(.leading, 16)

            pickerRow(
                icon: "arrow.down.circle.fill", iconColor: AppTheme.Colors.income,
                label: "Зачислить на счёт", value: toAccount.map { accountLabel($0) },
                hasError: didAttemptSave && (!toValid || sameAccount),
                errorText: sameAccount ? "Счета не должны совпадать" : "Выберите счёт зачисления"
            ) {
                ForEach(userAccounts) { acc in
                    Button {
                        toAccount = acc
                    } label: {
                        let sym = CurrencyInfo.symbol(for: acc.currency, custom: userCurrencies)
                        Text("\(acc.name)  \(accountService.currentBalance(for: acc), format: .number.precision(.fractionLength(0...2))) \(sym)")
                    }
                }
            }

            Divider().padding(.leading, 16)

            HStack(spacing: 12) {
                Image(systemName: "text.alignleft")
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                TextField("Заметка (необязательно)", text: $note)
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .cardStyle()
        .animation(.easeInOut(duration: 0.2), value: didAttemptSave)
    }

    private func handleSave() {
        withAnimation { didAttemptSave = true }
        guard let amt = amountDecimal, let from = fromAccount, let to = toAccount,
              !sameAccount, toAmountValid else { return }
        let crossAmt = toAmountDecimal

        if let editing = editingTransaction, editing.recurringGroupId != nil {
            pendingFrom = from; pendingTo = to; pendingAmount = amt; pendingToAmount = crossAmt
            showRecurringAlert = true
        } else if let editing = editingTransaction {
            let cd = date; let ce = endDate; let ci = interval; let cid = Int(intervalDays)
            let cr = recurringOperation; let cp = priority; let cn = note; let s = transactionService
            onSaved {
                s.deleteTransaction(editing)
                if !cr { s.addTransactions(from: from, to: to, amount: amt, toAmount: crossAmt, startDate: cd, priority: cp, note: cn) }
                else   { s.addTransactions(from: from, to: to, amount: amt, toAmount: crossAmt, startDate: cd, endDate: ce, interval: ci, intervalDays: cid, priority: cp, note: cn) }
            }
            isRootPresented = false; dismiss()
        } else {
            if !recurringOperation { transactionService.addTransactions(from: from, to: to, amount: amt, toAmount: crossAmt, startDate: date, priority: priority, note: note) }
            else { transactionService.addTransactions(from: from, to: to, amount: amt, toAmount: crossAmt, startDate: date, endDate: endDate, interval: interval, intervalDays: Int(intervalDays), priority: priority, note: note) }
            isRootPresented = false; dismiss()
        }
    }

    private func saveOnlyThis() {
        guard let from = pendingFrom, let to = pendingTo, let editing = editingTransaction else { return }
        let amt = pendingAmount; let ta = pendingToAmount; let cd = date; let cp = priority; let cn = note; let s = transactionService
        onSaved { s.deleteTransaction(editing); s.addTransactions(from: from, to: to, amount: amt, toAmount: ta, startDate: cd, priority: cp, note: cn) }
        isRootPresented = false; dismiss()
    }

    private func saveFollowing() {
        guard let from = pendingFrom, let to = pendingTo,
              let editing = editingTransaction, let groupId = editing.recurringGroupId else { return }
        let amt = pendingAmount; let ta = pendingToAmount; let cd = date; let ce = endDate; let ci = interval
        let cid = Int(intervalDays); let cr = recurringOperation; let cp = priority; let cn = note
        let ced = editing.date; let s = transactionService
        onSaved {
            s.deleteFollowingTransactions(groupId: groupId, from: ced)
            if !cr { s.addTransactions(from: from, to: to, amount: amt, toAmount: ta, startDate: cd, priority: cp, note: cn) }
            else   { s.addTransactions(from: from, to: to, amount: amt, toAmount: ta, startDate: cd, endDate: ce, interval: ci, intervalDays: cid, priority: cp, note: cn) }
        }
        isRootPresented = false; dismiss()
    }
}
