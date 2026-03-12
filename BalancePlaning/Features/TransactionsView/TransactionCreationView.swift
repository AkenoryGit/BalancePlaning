//
//  TransactionCreationView.swift
//  BalancePlaning
//
//  Created by Дмитрий Дудник on 10.03.2026.
//

import SwiftUI
import SwiftData

// MARK: - Выбор типа операции

struct TransactionsCategoryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var isTransactionPresented: Bool = false
    @State private var isExpensePresented: Bool = false
    @State private var isIncomePresented: Bool = false

    @Binding var isRootPresented: Bool

    var transactionService: TransactionService {
        TransactionService(context: context)
    }

    var body: some View {
        VStack {
            Button("Создать перевод") { isTransactionPresented = true }
                .buttonStyle(.borderedProminent).frame(maxWidth: .infinity).padding(.horizontal)
            Button("Создать расход") { isExpensePresented = true }
                .buttonStyle(.borderedProminent).frame(maxWidth: .infinity).padding(.horizontal)
            Button("Создать пополнение") { isIncomePresented = true }
                .buttonStyle(.borderedProminent).frame(maxWidth: .infinity).padding(.horizontal)
            Button("Отмена", role: .destructive) { dismiss() }
                .buttonStyle(.borderedProminent).frame(maxWidth: .infinity).padding(.horizontal)
        }
        .sheet(isPresented: $isTransactionPresented) {
            AddTransactionView(isRootPresented: $isRootPresented, transactionService: transactionService)
        }
        .sheet(isPresented: $isExpensePresented) {
            AddExpenseView(isRootPresented: $isRootPresented, transactionService: transactionService)
        }
        .sheet(isPresented: $isIncomePresented) {
            AddIncomeView(isRootPresented: $isRootPresented, transactionService: transactionService)
        }
    }
}

// MARK: - Настройки повторяющейся операции (общий компонент)

struct RecurringSettingsView: View {
    @Binding var date: Date
    @Binding var endDate: Date
    @Binding var interval: RecurringInterval?
    @Binding var intervalDays: String

    var body: some View {
        Picker("Интервал", selection: $interval) {
            ForEach(RecurringInterval.allCases, id: \.self) { i in
                Text(i.displayName).tag(Optional(i))
            }
        }
        if interval == .everyNDays {
            TextField("Количество дней", text: $intervalDays)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.numberPad)
                .padding(.horizontal)
        }
        DatePicker("Дата начала", selection: $date, displayedComponents: [.date])
            .datePickerStyle(.compact).padding()
        DatePicker(
            "Дата окончания",
            selection: $endDate,
            in: date...Calendar.current.date(byAdding: .year, value: 1, to: date)!,
            displayedComponents: [.date]
        )
        .datePickerStyle(.compact).padding()
    }
}

// MARK: - Добавление / редактирование перевода между счетами

struct AddTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query private var allUserAccounts: [Account]

    @Binding var isRootPresented: Bool

    @State var fromAccount: Account?
    @State var toAccount: Account?
    @State var amount: String = "0"
    @State var date: Date = Calendar.current.startOfDay(for: Date())
    @State var endDate: Date = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .year, value: 1, to: Date())!)
    @State var recurringOperation: Bool = false
    @State var interval: RecurringInterval? = .monthly
    @State var intervalDays: String = "2"

    var editingTransaction: Transaction? = nil
    // передаёт действие с БД наверх — родитель выполнит его после того как полностью исчезнет
    var onSaved: (@escaping () -> Void) -> Void = { _ in }

    @State private var showRecurringAlert: Bool = false
    @State private var pendingFrom: Account? = nil
    @State private var pendingTo: Account? = nil
    @State private var pendingAmount: Decimal = 0

    private var accountService: AccountService { AccountService(context: context) }
    private var userAccounts: [Account] {
        guard let userId = currentUserId() else { return [] }
        return allUserAccounts.filter { $0.userId == userId }
    }

    var transactionService: TransactionService

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    Spacer(minLength: 20)
                    Picker("Перевод со счёта", selection: $fromAccount) {
                        Text("Не выбрано").tag(Optional<Account>.none)
                        ForEach(userAccounts) { account in
                            Text("\(account.name) \(accountService.currentBalance(for: account), format: .number.precision(.fractionLength(0...2)))")
                                .tag(Optional(account))
                        }
                    }
                    .pickerStyle(.navigationLink)
                    Picker("Перевод на счёт", selection: $toAccount) {
                        Text("Не выбрано").tag(Optional<Account>.none)
                        ForEach(userAccounts) { account in
                            Text("\(account.name) \(accountService.currentBalance(for: account), format: .number.precision(.fractionLength(0...2)))")
                                .tag(Optional(account))
                        }
                    }
                    .pickerStyle(.navigationLink)
                    TextField("Сумма перевода", text: $amount)
                        .textFieldStyle(RoundedBorderTextFieldStyle()).keyboardType(.decimalPad).padding(.horizontal)
                    Toggle("Повторяющийся перевод", isOn: $recurringOperation).padding(.horizontal)
                    if recurringOperation {
                        RecurringSettingsView(date: $date, endDate: $endDate, interval: $interval, intervalDays: $intervalDays)
                    } else {
                        DatePicker("Выберите дату", selection: $date, displayedComponents: [.date])
                            .datePickerStyle(.graphical).padding()
                    }
                    Button(editingTransaction == nil ? "Добавить" : "Сохранить") {
                        guard let from = fromAccount, let to = toAccount,
                              let amountDecimal = Decimal(string: amount), amountDecimal > 0 else {
                            print("Ошибка заполнения полей"); return
                        }
                        if let editing = editingTransaction, editing.recurringGroupId != nil {
                            pendingFrom = from; pendingTo = to; pendingAmount = amountDecimal
                            showRecurringAlert = true
                        } else if let editing = editingTransaction {
                            let capturedDate = date; let capturedEndDate = endDate
                            let capturedInterval = interval; let capturedIntervalDays = Int(intervalDays)
                            let capturedRecurring = recurringOperation; let capturedAmount = amountDecimal
                            let service = transactionService
                            onSaved {
                                service.deleteTransaction(editing)
                                if !capturedRecurring {
                                    service.addTransactions(from: from, to: to, amount: capturedAmount, startDate: capturedDate)
                                } else {
                                    service.addTransactions(from: from, to: to, amount: capturedAmount, startDate: capturedDate, endDate: capturedEndDate, interval: capturedInterval, intervalDays: capturedIntervalDays)
                                }
                            }
                            isRootPresented = false; dismiss()
                        } else {
                            if !recurringOperation {
                                transactionService.addTransactions(from: from, to: to, amount: amountDecimal, startDate: date)
                            } else {
                                transactionService.addTransactions(from: from, to: to, amount: amountDecimal, startDate: date, endDate: endDate, interval: interval, intervalDays: Int(intervalDays))
                            }
                            isRootPresented = false; dismiss()
                        }
                    }
                    .alert("Изменить повторяющуюся операцию?", isPresented: $showRecurringAlert) {
                        Button("Только эту") {
                            guard let from = pendingFrom, let to = pendingTo,
                                  let editing = editingTransaction else { return }
                            let capturedDate = date; let capturedAmount = pendingAmount
                            let service = transactionService
                            onSaved {
                                service.deleteTransaction(editing)
                                service.addTransactions(from: from, to: to, amount: capturedAmount, startDate: capturedDate)
                            }
                            isRootPresented = false; dismiss()
                        }
                        Button("Все последующие") {
                            guard let from = pendingFrom, let to = pendingTo,
                                  let editing = editingTransaction,
                                  let groupId = editing.recurringGroupId else { return }
                            let capturedDate = date; let capturedEndDate = endDate
                            let capturedInterval = interval; let capturedIntervalDays = Int(intervalDays)
                            let capturedRecurring = recurringOperation; let capturedAmount = pendingAmount
                            let capturedEditingDate = editing.date; let service = transactionService
                            onSaved {
                                service.deleteFollowingTransactions(groupId: groupId, from: capturedEditingDate)
                                if !capturedRecurring {
                                    service.addTransactions(from: from, to: to, amount: capturedAmount, startDate: capturedDate)
                                } else {
                                    service.addTransactions(from: from, to: to, amount: capturedAmount, startDate: capturedDate, endDate: capturedEndDate, interval: capturedInterval, intervalDays: capturedIntervalDays)
                                }
                            }
                            isRootPresented = false; dismiss()
                        }
                        Button("Отмена", role: .cancel) {}
                    }
                    Button("Отмена", role: .destructive) { dismiss() }
                        .buttonStyle(.borderedProminent).frame(maxWidth: .infinity).padding(.horizontal)
                }
            }
        }
    }
}

// MARK: - Добавление / редактирование расхода

struct AddExpenseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query private var allUserAccounts: [Account]
    @Query private var allCategories: [Category]

    @Binding var isRootPresented: Bool

    @State var fromAccount: Account?
    @State var toCategory: Category?
    @State var amount: String = "0"
    @State var date: Date = Calendar.current.startOfDay(for: Date())
    @State var endDate: Date = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .year, value: 1, to: Date())!)
    @State var recurringOperation: Bool = false
    @State var interval: RecurringInterval? = .monthly
    @State var intervalDays: String = "2"

    var editingTransaction: Transaction? = nil
    var onSaved: (@escaping () -> Void) -> Void = { _ in }

    @State private var showRecurringAlert: Bool = false
    @State private var pendingFrom: Account? = nil
    @State private var pendingTo: Category? = nil
    @State private var pendingAmount: Decimal = 0

    private var accountService: AccountService { AccountService(context: context) }
    private var userAccounts: [Account] {
        guard let userId = currentUserId() else { return [] }
        return allUserAccounts.filter { $0.userId == userId }
    }
    private var expenseCategories: [Category] {
        guard let userId = currentUserId() else { return [] }
        return allCategories.filter { $0.userId == userId && $0.type == .expense }
    }

    var transactionService: TransactionService

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    Spacer(minLength: 20)
                    Picker("Оплата со счёта", selection: $fromAccount) {
                        Text("Не выбрано").tag(Optional<Account>.none)
                        ForEach(userAccounts) { account in
                            Text("\(account.name) \(accountService.currentBalance(for: account), format: .number.precision(.fractionLength(0...2)))")
                                .tag(Optional(account))
                        }
                    }
                    .pickerStyle(.navigationLink)
                    Picker("Категория расхода", selection: $toCategory) {
                        Text("Не выбрано").tag(Optional<Category>.none)
                        ForEach(expenseCategories) { category in
                            Text(category.name).tag(Optional(category))
                        }
                    }
                    .pickerStyle(.navigationLink)
                    TextField("Сумма оплаты", text: $amount)
                        .textFieldStyle(RoundedBorderTextFieldStyle()).keyboardType(.decimalPad).padding(.horizontal)
                    Toggle("Повторяющийся расход", isOn: $recurringOperation).padding(.horizontal)
                    if recurringOperation {
                        RecurringSettingsView(date: $date, endDate: $endDate, interval: $interval, intervalDays: $intervalDays)
                    } else {
                        DatePicker("Выберите дату", selection: $date, displayedComponents: [.date])
                            .datePickerStyle(.graphical).padding()
                    }
                    Button(editingTransaction == nil ? "Добавить" : "Сохранить") {
                        guard let from = fromAccount, let to = toCategory,
                              let amountDecimal = Decimal(string: amount), amountDecimal > 0 else {
                            print("Ошибка заполнения полей"); return
                        }
                        if let editing = editingTransaction, editing.recurringGroupId != nil {
                            pendingFrom = from; pendingTo = to; pendingAmount = amountDecimal
                            showRecurringAlert = true
                        } else if let editing = editingTransaction {
                            let capturedDate = date; let capturedEndDate = endDate
                            let capturedInterval = interval; let capturedIntervalDays = Int(intervalDays)
                            let capturedRecurring = recurringOperation; let capturedAmount = amountDecimal
                            let service = transactionService
                            onSaved {
                                service.deleteTransaction(editing)
                                if !capturedRecurring {
                                    service.addExpense(from: from, to: to, amount: capturedAmount, startDate: capturedDate)
                                } else {
                                    service.addExpense(from: from, to: to, amount: capturedAmount, startDate: capturedDate, endDate: capturedEndDate, interval: capturedInterval, intervalDays: capturedIntervalDays)
                                }
                            }
                            isRootPresented = false; dismiss()
                        } else {
                            if !recurringOperation {
                                transactionService.addExpense(from: from, to: to, amount: amountDecimal, startDate: date)
                            } else {
                                transactionService.addExpense(from: from, to: to, amount: amountDecimal, startDate: date, endDate: endDate, interval: interval, intervalDays: Int(intervalDays))
                            }
                            isRootPresented = false; dismiss()
                        }
                    }
                    .alert("Изменить повторяющуюся операцию?", isPresented: $showRecurringAlert) {
                        Button("Только эту") {
                            guard let from = pendingFrom, let to = pendingTo,
                                  let editing = editingTransaction else { return }
                            let capturedDate = date; let capturedAmount = pendingAmount
                            let service = transactionService
                            onSaved {
                                service.deleteTransaction(editing)
                                service.addExpense(from: from, to: to, amount: capturedAmount, startDate: capturedDate)
                            }
                            isRootPresented = false; dismiss()
                        }
                        Button("Все последующие") {
                            guard let from = pendingFrom, let to = pendingTo,
                                  let editing = editingTransaction,
                                  let groupId = editing.recurringGroupId else { return }
                            let capturedDate = date; let capturedEndDate = endDate
                            let capturedInterval = interval; let capturedIntervalDays = Int(intervalDays)
                            let capturedRecurring = recurringOperation; let capturedAmount = pendingAmount
                            let capturedEditingDate = editing.date; let service = transactionService
                            onSaved {
                                service.deleteFollowingTransactions(groupId: groupId, from: capturedEditingDate)
                                if !capturedRecurring {
                                    service.addExpense(from: from, to: to, amount: capturedAmount, startDate: capturedDate)
                                } else {
                                    service.addExpense(from: from, to: to, amount: capturedAmount, startDate: capturedDate, endDate: capturedEndDate, interval: capturedInterval, intervalDays: capturedIntervalDays)
                                }
                            }
                            isRootPresented = false; dismiss()
                        }
                        Button("Отмена", role: .cancel) {}
                    }
                    Button("Отмена", role: .destructive) { dismiss() }
                        .buttonStyle(.borderedProminent).frame(maxWidth: .infinity).padding(.horizontal)
                }
            }
        }
    }
}

// MARK: - Добавление / редактирование пополнения

struct AddIncomeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query private var allUserAccounts: [Account]
    @Query private var allCategories: [Category]

    @Binding var isRootPresented: Bool

    @State var fromCategory: Category?
    @State var toAccount: Account?
    @State var amount: String = "0"
    @State var date: Date = Calendar.current.startOfDay(for: Date())
    @State var endDate: Date = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .year, value: 1, to: Date())!)
    @State var recurringOperation: Bool = false
    @State var interval: RecurringInterval? = .monthly
    @State var intervalDays: String = "2"

    var editingTransaction: Transaction? = nil
    var onSaved: (@escaping () -> Void) -> Void = { _ in }

    @State private var showRecurringAlert: Bool = false
    @State private var pendingFrom: Category? = nil
    @State private var pendingTo: Account? = nil
    @State private var pendingAmount: Decimal = 0

    private var accountService: AccountService { AccountService(context: context) }
    private var userAccounts: [Account] {
        guard let userId = currentUserId() else { return [] }
        return allUserAccounts.filter { $0.userId == userId }
    }
    private var incomeCategories: [Category] {
        guard let userId = currentUserId() else { return [] }
        return allCategories.filter { $0.userId == userId && $0.type == .income }
    }

    var transactionService: TransactionService

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    Spacer(minLength: 20)
                    Picker("Категория поступления", selection: $fromCategory) {
                        Text("Не выбрано").tag(Optional<Category>.none)
                        ForEach(incomeCategories) { category in
                            Text(category.name).tag(Optional(category))
                        }
                    }
                    .pickerStyle(.navigationLink)
                    Picker("Поступление на счёт", selection: $toAccount) {
                        Text("Не выбрано").tag(Optional<Account>.none)
                        ForEach(userAccounts) { account in
                            Text("\(account.name) \(accountService.currentBalance(for: account), format: .number.precision(.fractionLength(0...2)))")
                                .tag(Optional(account))
                        }
                    }
                    .pickerStyle(.navigationLink)
                    TextField("Сумма поступления", text: $amount)
                        .textFieldStyle(RoundedBorderTextFieldStyle()).keyboardType(.decimalPad).padding(.horizontal)
                    Toggle("Повторяющееся поступление", isOn: $recurringOperation).padding(.horizontal)
                    if recurringOperation {
                        RecurringSettingsView(date: $date, endDate: $endDate, interval: $interval, intervalDays: $intervalDays)
                    } else {
                        DatePicker("Выберите дату", selection: $date, displayedComponents: [.date])
                            .datePickerStyle(.graphical).padding()
                    }
                    Button(editingTransaction == nil ? "Добавить" : "Сохранить") {
                        guard let from = fromCategory, let to = toAccount,
                              let amountDecimal = Decimal(string: amount), amountDecimal > 0 else {
                            print("Ошибка заполнения полей"); return
                        }
                        if let editing = editingTransaction, editing.recurringGroupId != nil {
                            pendingFrom = from; pendingTo = to; pendingAmount = amountDecimal
                            showRecurringAlert = true
                        } else if let editing = editingTransaction {
                            let capturedDate = date; let capturedEndDate = endDate
                            let capturedInterval = interval; let capturedIntervalDays = Int(intervalDays)
                            let capturedRecurring = recurringOperation; let capturedAmount = amountDecimal
                            let service = transactionService
                            onSaved {
                                service.deleteTransaction(editing)
                                if !capturedRecurring {
                                    service.addIncome(from: from, to: to, amount: capturedAmount, startDate: capturedDate)
                                } else {
                                    service.addIncome(from: from, to: to, amount: capturedAmount, startDate: capturedDate, endDate: capturedEndDate, interval: capturedInterval, intervalDays: capturedIntervalDays)
                                }
                            }
                            isRootPresented = false; dismiss()
                        } else {
                            if !recurringOperation {
                                transactionService.addIncome(from: from, to: to, amount: amountDecimal, startDate: date)
                            } else {
                                transactionService.addIncome(from: from, to: to, amount: amountDecimal, startDate: date, endDate: endDate, interval: interval, intervalDays: Int(intervalDays))
                            }
                            isRootPresented = false; dismiss()
                        }
                    }
                    .alert("Изменить повторяющуюся операцию?", isPresented: $showRecurringAlert) {
                        Button("Только эту") {
                            guard let from = pendingFrom, let to = pendingTo,
                                  let editing = editingTransaction else { return }
                            let capturedDate = date; let capturedAmount = pendingAmount
                            let service = transactionService
                            onSaved {
                                service.deleteTransaction(editing)
                                service.addIncome(from: from, to: to, amount: capturedAmount, startDate: capturedDate)
                            }
                            isRootPresented = false; dismiss()
                        }
                        Button("Все последующие") {
                            guard let from = pendingFrom, let to = pendingTo,
                                  let editing = editingTransaction,
                                  let groupId = editing.recurringGroupId else { return }
                            let capturedDate = date; let capturedEndDate = endDate
                            let capturedInterval = interval; let capturedIntervalDays = Int(intervalDays)
                            let capturedRecurring = recurringOperation; let capturedAmount = pendingAmount
                            let capturedEditingDate = editing.date; let service = transactionService
                            onSaved {
                                service.deleteFollowingTransactions(groupId: groupId, from: capturedEditingDate)
                                if !capturedRecurring {
                                    service.addIncome(from: from, to: to, amount: capturedAmount, startDate: capturedDate)
                                } else {
                                    service.addIncome(from: from, to: to, amount: capturedAmount, startDate: capturedDate, endDate: capturedEndDate, interval: capturedInterval, intervalDays: capturedIntervalDays)
                                }
                            }
                            isRootPresented = false; dismiss()
                        }
                        Button("Отмена", role: .cancel) {}
                    }
                    Button("Отмена", role: .destructive) { dismiss() }
                        .buttonStyle(.borderedProminent).frame(maxWidth: .infinity).padding(.horizontal)
                }
            }
        }
    }
}

// MARK: - Редактирование транзакции

struct EditTransactionView: View {
    @Environment(\.modelContext) private var context

    @Binding var isRootPresented: Bool
    let transaction: Transaction
    var onSaved: (@escaping () -> Void) -> Void = { _ in }

    var transactionService: TransactionService { TransactionService(context: context) }

    var body: some View {
        if transaction.type == .income {
            AddIncomeView(
                isRootPresented: $isRootPresented,
                fromCategory: transaction.fromCategory,
                toAccount: transaction.toAccount,
                amount: transaction.amount.description,
                date: transaction.date,
                recurringOperation: transaction.recurringGroupId != nil,
                interval: transaction.recurringInterval,
                intervalDays: String(transaction.recurringIntervalDays ?? 2),
                editingTransaction: transaction,
                onSaved: onSaved,
                transactionService: transactionService
            )
        } else if transaction.type == .expense {
            AddExpenseView(
                isRootPresented: $isRootPresented,
                fromAccount: transaction.fromAccount,
                toCategory: transaction.toCategory,
                amount: transaction.amount.description,
                date: transaction.date,
                recurringOperation: transaction.recurringGroupId != nil,
                interval: transaction.recurringInterval,
                intervalDays: String(transaction.recurringIntervalDays ?? 2),
                editingTransaction: transaction,
                onSaved: onSaved,
                transactionService: transactionService
            )
        } else {
            AddTransactionView(
                isRootPresented: $isRootPresented,
                fromAccount: transaction.fromAccount,
                toAccount: transaction.toAccount,
                amount: transaction.amount.description,
                date: transaction.date,
                recurringOperation: transaction.recurringGroupId != nil,
                interval: transaction.recurringInterval,
                intervalDays: String(transaction.recurringIntervalDays ?? 2),
                editingTransaction: transaction,
                onSaved: onSaved,
                transactionService: transactionService
            )
        }
    }
}
