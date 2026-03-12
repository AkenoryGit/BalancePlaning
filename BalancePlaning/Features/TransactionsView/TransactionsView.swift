//
//  TransactionsView.swift
//  BalancePlaning
//
//  Created by Дмитрий Дудник on 26.02.2026.
//

import SwiftUI
import SwiftData

struct TransactionsView: View {
    @Environment(\.modelContext) var context
    @State private var date: Date = Date.now
    @State private var isPresented: Bool = false
    @State private var showDatePicker: Bool = false
    @State private var showAllTransactions: Bool = false
    @State private var selectedTransacion: Transaction?
    
    @Query private var allTransactions: [Transaction]
    
    private var userTransactions: [Transaction] {
        guard let userId = currentUserId() else {
            return []
        }
        return allTransactions.filter { $0.userId == userId }
    }
    
    private var dailyTransactions: [Transaction] {
        userTransactions.filter {
            Calendar.current.isDate($0.date, inSameDayAs: date)
        }
    }
    
    var topHead = TopHead(title: "Транзакции")

    private var accountService: AccountService {
        AccountService(context: context)
    }
    
    var body: some View {
        VStack {
            topHead
                .frame(height: 50)
                .padding(.top)
            Text("Всего денег: ")
                .font(.largeTitle)
                .padding(.top, 30)
            Text(accountService.totalBalance(at: date), format: .number.precision(.fractionLength(0...2)))
                .font(.largeTitle.bold())
            if !showAllTransactions {
                HStack {
                    Button {
                        date = Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
                    } label: {
                        Image(systemName: "arrow.backward.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    Button(date.formatted(.dateTime
                        .locale(Locale(identifier: "ru_RU"))
                        .year(.defaultDigits)
                        .month(.defaultDigits)
                        .day(.defaultDigits)
                        .weekday(.wide)
                    )) {
                        showDatePicker = true
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .sheet(isPresented: $showDatePicker) {
                        DatePicker("", selection: $date, displayedComponents: [.date])
                            .datePickerStyle(.graphical)
                            .environment(\.locale, Locale(identifier: "ru_RU"))
                            .presentationDetents([.medium])
                        Button {
                            showAllTransactions = true
                            showDatePicker = false
                        } label: {
                            Text("Показать все операции")
                        }
                    }
                    Button {
                        date = Calendar.current.date(byAdding: .day, value: +1, to: date) ?? date
                    } label: {
                        Image(systemName: "arrow.forward.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                }
            } else {
                Button {
                    showAllTransactions = false
                } label: {
                    Text("Выбрать по дате")
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .padding(.top, 20)
            }
            ScrollView {
                if !showAllTransactions {
                    ForEach(dailyTransactions, id: \.self) { transaction in
                        Button(action: {
                            selectedTransacion = transaction
                        }) {
                            Spacer()
                            Text("\(transaction.type.displayName) : \(transaction.date, format: .dateTime.day(.twoDigits).month(.twoDigits).year(.twoDigits)) - \(transaction.amount , format: .number.precision(.fractionLength(0...2))) руб")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                    }
                } else {
                    ForEach(userTransactions.sorted { $0.date < $1.date} ) { transaction in
                        Button(action: {
                            selectedTransacion = transaction
                        }) {
                            Spacer()
                            Text("\(transaction.type.displayName) : \(transaction.date, format: .dateTime.day(.twoDigits).month(.twoDigits).year(.twoDigits)) - \(transaction.amount , format: .number.precision(.fractionLength(0...2))) руб")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                    }
                }
            }
            .sheet(item: $selectedTransacion) { transaction in
                TransactionDetailView(transaction: transaction, selectedTransaction: $selectedTransacion)
            }
            
            Button("Добавить операцию") {
                isPresented = true
            }
        }
        .sheet(isPresented: $isPresented) {
            TransactionsCategoryView(isRootPresented: $isPresented)
        }
    }
}

struct TransactionDetailView: View {
    @Environment(\.modelContext) private var context

    let transaction: Transaction
    // биндинг на selectedTransacion в родителе — нужен чтобы обнулить его ДО удаления
    @Binding var selectedTransaction: Transaction?

    @State private var showEdit: Bool = false
    @State private var showDeleteAlert: Bool = false
    @State private var editWasSaved: Bool = false
    // действие с БД, которое выполняется в .onDisappear, когда View полностью исчезла
    @State private var pendingAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 20) {
            Text("Детали операции:")
                .font(.largeTitle)
            Text("\(transaction.type.displayName) \(transaction.date, format: .dateTime.day(.twoDigits).month(.twoDigits).year(.twoDigits))")
                .font(.title2)
            Text("На сумму ^[\(transaction.amount, format: .number)](bold: true) руб")
                .bold()
            if transaction.type == .income {
                Text("Пополнение баланса счета \(transaction.toAccount?.name ?? "неизвестно")")
                Text("С категории \(transaction.fromCategory?.name ?? "неизвестно")")
            } else if transaction.type == .expense {
                Text("Платёж со счета \(transaction.fromAccount?.name ?? "неизвестно")")
                Text("По категории \(transaction.toCategory?.name ?? "неизвестно")")
            } else {
                Text("Перевод со счета \(transaction.fromAccount?.name ?? "неизвестно")")
                Text("На счет \(transaction.toAccount?.name ?? "неизвестно")")
            }
            Button("Редактировать") {
                editWasSaved = false
                showEdit = true
            }
            .sheet(isPresented: $showEdit) {
                EditTransactionView(
                    isRootPresented: $showEdit,
                    transaction: transaction,
                    onSaved: { action in
                        pendingAction = action
                        editWasSaved = true
                    }
                )
            }
            // когда шит редактирования закрылся и было сохранение — закрываем Detail View тоже
            .onChange(of: showEdit) { _, isShowing in
                if !isShowing && editWasSaved {
                    selectedTransaction = nil
                }
            }
            Button("Удалить операцию") {
                if transaction.recurringGroupId != nil {
                    showDeleteAlert = true
                } else {
                    let service = TransactionService(context: context)
                    pendingAction = { service.deleteTransaction(transaction) }
                    selectedTransaction = nil
                }
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
            Button("Закрыть окно") {
                selectedTransaction = nil
            }
        }
        .onDisappear {
            pendingAction?()
            pendingAction = nil
        }
    }
}
