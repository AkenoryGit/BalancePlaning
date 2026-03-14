//
//  AddIncomeView.swift
//  BalancePlaning
//

import SwiftUI
import SwiftData

struct AddIncomeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query private var allUserAccounts: [Account]
    @Query private var allCategories: [Category]
    @Query private var allCurrencies: [Currency]
    @Query private var allGroups: [AccountGroup]

    @Binding var isRootPresented: Bool

    @State var fromCategory: Category?
    @State var toAccount: Account?
    @State var amount: String = ""
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
    @State private var pendingFrom: Category?
    @State private var pendingTo: Account?
    @State private var pendingAmount: Decimal = 0

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
    private var incomeCategories: [Category] {
        guard let userId = currentUserId() else { return [] }
        return CategoryService.sortedTree(from: allCategories.filter { $0.userId == userId && $0.type == .income })
    }

    private var amountDecimal: Decimal? {
        let s = amount.replacingOccurrences(of: ",", with: ".")
        guard let d = Decimal(string: s), d > 0 else { return nil }
        return d
    }
    private var amountValid: Bool { amountDecimal != nil }
    private var fromValid:   Bool { fromCategory != nil }
    private var toValid:     Bool { toAccount != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    AmountInputCard(
                        icon: "plus.circle.fill",
                        typeLabel: "Пополнение",
                        color: AppTheme.Colors.income,
                        amount: $amount,
                        showError: didAttemptSave && !amountValid
                    )

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
            .navigationTitle(editingTransaction == nil ? "Новое пополнение" : "Изменить пополнение")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }.foregroundStyle(.secondary)
                }
            }
            .safeAreaInset(edge: .bottom) {
                TransactionSaveBar(
                    label: editingTransaction == nil ? "Добавить пополнение" : "Сохранить изменения",
                    color: AppTheme.Colors.income,
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
                icon: "tag", iconColor: AppTheme.Colors.income,
                label: "Категория", value: fromCategory.map { CategoryService.breadcrumb(for: $0, in: incomeCategories) },
                hasError: didAttemptSave && !fromValid, errorText: "Выберите категорию"
            ) {
                ForEach(incomeCategories) { cat in
                    Button(CategoryService.displayLabel(for: cat)) { fromCategory = cat }
                }
            }

            Divider().padding(.leading, 16)

            pickerRow(
                icon: "creditcard", iconColor: AppTheme.Colors.accent,
                label: "На счёт", value: toAccount.map { accountLabel($0) },
                hasError: didAttemptSave && !toValid, errorText: "Выберите счёт"
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
        guard let amt = amountDecimal, let from = fromCategory, let to = toAccount else { return }

        if let editing = editingTransaction, editing.recurringGroupId != nil {
            pendingFrom = from; pendingTo = to; pendingAmount = amt
            showRecurringAlert = true
        } else if let editing = editingTransaction {
            let cd = date; let ce = endDate; let ci = interval; let cid = Int(intervalDays)
            let cr = recurringOperation; let cp = priority; let cn = note; let s = transactionService
            onSaved {
                s.deleteTransaction(editing)
                if !cr { s.addIncome(from: from, to: to, amount: amt, startDate: cd, priority: cp, note: cn) }
                else   { s.addIncome(from: from, to: to, amount: amt, startDate: cd, endDate: ce, interval: ci, intervalDays: cid, priority: cp, note: cn) }
            }
            isRootPresented = false; dismiss()
        } else {
            if !recurringOperation { transactionService.addIncome(from: from, to: to, amount: amt, startDate: date, priority: priority, note: note) }
            else { transactionService.addIncome(from: from, to: to, amount: amt, startDate: date, endDate: endDate, interval: interval, intervalDays: Int(intervalDays), priority: priority, note: note) }
            isRootPresented = false; dismiss()
        }
    }

    private func saveOnlyThis() {
        guard let from = pendingFrom, let to = pendingTo, let editing = editingTransaction else { return }
        let amt = pendingAmount; let cd = date; let cp = priority; let cn = note; let s = transactionService
        onSaved { s.deleteTransaction(editing); s.addIncome(from: from, to: to, amount: amt, startDate: cd, priority: cp, note: cn) }
        isRootPresented = false; dismiss()
    }

    private func saveFollowing() {
        guard let from = pendingFrom, let to = pendingTo,
              let editing = editingTransaction, let groupId = editing.recurringGroupId else { return }
        let amt = pendingAmount; let cd = date; let ce = endDate; let ci = interval
        let cid = Int(intervalDays); let cr = recurringOperation; let cp = priority; let cn = note
        let ced = editing.date; let s = transactionService
        onSaved {
            s.deleteFollowingTransactions(groupId: groupId, from: ced)
            if !cr { s.addIncome(from: from, to: to, amount: amt, startDate: cd, priority: cp, note: cn) }
            else   { s.addIncome(from: from, to: to, amount: amt, startDate: cd, endDate: ce, interval: ci, intervalDays: cid, priority: cp, note: cn) }
        }
        isRootPresented = false; dismiss()
    }
}
