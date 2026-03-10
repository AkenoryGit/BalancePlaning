//
//  TransactionsView.swift
//  BalancePlaning
//
//  Created by Дмитрий Дудник on 26.02.2026.
//

import SwiftUI
import SwiftData

struct TransactionsView: View {
    @State private var date: Date = Date.now
    @State private var isPresented: Bool = false
    
    @Query private var allTransactions: [Transaction]
    
    private var userTransactions: [Transaction] {
        guard let userId = currentUserId() else {
            return []
        }
        return allTransactions.filter { $0.userId == userId }
    }
    
    var topHead = TopHead(title: "Транзакции")
    
    var body: some View {
        VStack {
            topHead
                .frame(height: 50)
                .padding(.top)
            Button(date.formatted(.dateTime
                .locale(Locale(identifier: "ru_RU"))
                .year(.defaultDigits)
                .month(.defaultDigits)
                .day(.defaultDigits)
                .weekday(.wide)
            )) {
                
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
            .padding(.top, 20)
            
            ForEach(userTransactions) { transaction in
                Button(action: {
                    
                }) {
                    Spacer()
                    Text("\(transaction.type.displayName) : \(transaction.date, format: .dateTime.day(.twoDigits).month(.twoDigits).year(.twoDigits)) - \(transaction.amount) руб")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                }
            }
            Spacer()
            
            Button("Добавить операцию") {
                isPresented = true
            }
        }
        .sheet(isPresented: $isPresented) {
            TransactionsCategoryView()
        }
    }
}

struct TransactionsCategoryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @State private var isTransactionPresented: Bool = false
    @State private var isExpensePresented: Bool = false
    @State private var isIncomePresented: Bool = false
    
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
            AddTransactionView(transactionService: transactionService)
        }
        .sheet(isPresented: $isExpensePresented) {
            AddExpenseView()
        }
        .sheet(isPresented: $isIncomePresented) {
            AddIncomeView()
        }
    }
}

struct AddTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    @Query private var allUserAccounts: [Account]
    @Query private var allCategories: [Category]
    
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
    
    private var userCategories: [Category] {
        guard let userId = currentUserId() else {
            return []
        }
        return allCategories.filter { $0.userId == userId }
    }
    private var expenseCategories: [Category] {
        userCategories.filter { $0.type == .expense }
    }
    private var incomeCategories: [Category] {
        userCategories.filter { $0.type == .income }
    }
    
    var transactionService: TransactionService
    
    var body: some View {
        NavigationStack {
            VStack {
                Picker("Перевод со счёта", selection: $fromAccount) {
                    ForEach(allUserAccounts) { account in
                        Text("\(account.name) \(accountService.currentBalance(for: account))")
                            .tag(Optional(account))
                    }
                }
                .pickerStyle(.navigationLink)
                Picker("Перевод на счёт", selection: $toAccount) {
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
    
    var body: some View {
        
    }
}

struct AddIncomeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    var body: some View {
        
    }
}

//#Preview {
//    TransactionsView(topHead: TopHead(title: "Транзакции"))
//}
