//
//  TransactionCreationView.swift
//  BalancePlaning
//
//  Created by Дмитрий Дудник on 10.03.2026.
//

import SwiftUI
import SwiftData

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
        VStack{
            Button("Создать перевод") {
                isTransactionPresented = true
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
            Button("Создать расход") {
                isExpensePresented = true
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
            Button("Создать пополнение") {
                isIncomePresented = true
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
            Button("Отмена", role: .destructive) {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
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

struct AddTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    @Query private var allUserAccounts: [Account]
    
    @Binding var isRootPresented: Bool
    
    @State var fromAccount: Account?
    @State var toAccount: Account?
    @State var amount: String = "0"
    @State var date: Date = Calendar.current.startOfDay(for: Date())
    
    private var accountService: AccountService {
        AccountService(context: context)
    }
    
    private var userAccounts: [Account] {
        guard let userId = currentUserId() else {
            return []
        }
        return allUserAccounts.filter { $0.userId == userId }
    }
    
    var transactionService: TransactionService
    
    var body: some View {
        NavigationStack {
            VStack {
                Picker("Перевод со счёта", selection: $fromAccount) {
                    Text("Не выбрано").tag(Optional<Account>.none)
                    ForEach(allUserAccounts) { account in
                        Text("\(account.name) \(accountService.currentBalance(for: account))")
                            .tag(Optional(account))
                    }
                }
                .pickerStyle(.navigationLink)
                Picker("Перевод на счёт", selection: $toAccount) {
                    Text("Не выбрано").tag(Optional<Account>.none)
                    ForEach(allUserAccounts) { account in
                        Text("\(account.name) \(accountService.currentBalance(for: account))")
                            .tag(Optional(account))
                    }
                }
                .pickerStyle(.navigationLink)
                TextField("Сумма перевода", text: $amount)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.decimalPad)
                DatePicker(
                    "Выберите дату",
                    selection: $date,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .padding()
                Button("Добавить") {
                    guard let from = fromAccount,
                          let to = toAccount,
                          let amountDecimal = Decimal(string: amount),
                          amountDecimal > 0 else {
                        print("Ошибка заполнения полей")
                        return
                    }
                    transactionService.addTransactions(from: from, to: to, amount: amountDecimal, date: date)
                    isRootPresented = false
                    dismiss()
                }
                Button("Отмена", role: .destructive) {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
            }
        }
    }
}

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
    
    private var accountService: AccountService {
        AccountService(context: context)
    }
    
    private var userAccounts: [Account] {
        guard let userId = currentUserId() else {
            return []
        }
        return allUserAccounts.filter { $0.userId == userId }
    }
    
        private var expenseCategories: [Category] {
            guard let userId = currentUserId() else {
                return []
            }
            return allCategories.filter { $0.userId == userId && $0.type == .expense }
        }
    
    var transactionService: TransactionService
    
    var body: some View {
        NavigationStack {
            VStack {
                Picker("Оплата со счёта", selection: $fromAccount) {
                    ForEach(allUserAccounts) { account in
                        Text("Не выбрано").tag(Optional<Account>.none)
                        Text("\(account.name) \(accountService.currentBalance(for: account))")
                            .tag(Optional(account))
                    }
                }
                .pickerStyle(.navigationLink)
                Picker("Оплата категории", selection: $toCategory) {
                    Text("Не выбрано").tag(Optional<Category>.none)
                    ForEach(expenseCategories) { category in
                        Text("\(category.name)")
                            .tag(Optional(category))
                    }
                }
                .pickerStyle(.navigationLink)
                TextField("Сумма оплаты", text: $amount)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.decimalPad)
                DatePicker(
                    "Выберите дату",
                    selection: $date,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .padding()
                Button("Добавить") {
                    guard let from = fromAccount,
                          let to = toCategory,
                          let amountDecimal = Decimal(string: amount),
                          amountDecimal > 0 else {
                        print("Ошибка заполнения полей")
                        return
                    }
                    transactionService.addExpenense(from: from, to: to, amount: amountDecimal, date: date)
                    isRootPresented = false
                    dismiss()
                }
                Button("Отмена", role: .destructive) {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
            }
        }
    }
}

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
    
    private var accountService: AccountService {
        AccountService(context: context)
    }
    
    private var userAccounts: [Account] {
        guard let userId = currentUserId() else {
            return []
        }
        return allUserAccounts.filter { $0.userId == userId }
    }
    
    private var incomeCategories: [Category] {
        guard let userId = currentUserId() else {
            return []
        }
        return allCategories.filter { $0.userId == userId && $0.type == .income }
    }
    
    var transactionService: TransactionService
    
    var body: some View {
        NavigationStack {
            VStack {
                Picker("Поступление с категории", selection: $fromCategory) {
                    Text("Не выбрано").tag(Optional<Category>.none)
                    ForEach(incomeCategories) { category in
                        Text("\(category.name)")
                            .tag(Optional(category))
                    }
                }
                .pickerStyle(.navigationLink)
                Picker("Поступление на счёт", selection: $toAccount) {
                    Text("Не выбрано").tag(Optional<Account>.none)
                    ForEach(userAccounts) { account in
                        Text("\(account.name) \(accountService.currentBalance(for: account))")
                            .tag(Optional(account))
                    }
                }
                .pickerStyle(.navigationLink)
                TextField("Сумма поступления", text: $amount)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.decimalPad)
                DatePicker(
                    "Выберите дату",
                    selection: $date,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .padding()
                Button("Добавить") {
                    guard let from = fromCategory,
                          let to = toAccount,
                          let amountDecimal = Decimal(string: amount),
                          amountDecimal > 0 else {
                        print("Ошибка заполнения полей")
                        return
                    }
                    transactionService.addIncome(from: from, to: to, amount: amountDecimal, date: date)
                    isRootPresented = false
                    dismiss()
                }
                Button("Отмена", role: .destructive) {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
            }
        }
    }
}

