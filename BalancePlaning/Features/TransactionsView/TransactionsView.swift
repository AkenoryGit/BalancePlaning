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
    @State private var showDatePicker: Bool = false
    @State private var showAllTransactions: Bool = false
    @State private var isSelected: Bool = false
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
    
    var body: some View {
        VStack {
            topHead
                .frame(height: 50)
                .padding(.top)
            if !showAllTransactions {
                HStack {
                    Button {
                        date = Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
                    } label: {
                        Image(systemName: "arrow.backward.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
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
                    .padding(.top, 20)
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
                    .padding(.top, 20)
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
            if !showAllTransactions {
                ForEach(dailyTransactions, id: \.self) { transaction in
                    Button(action: {
                        selectedTransacion = transaction
                    }) {
                        Spacer()
                        Text("\(transaction.type.displayName) : \(transaction.date, format: .dateTime.day(.twoDigits).month(.twoDigits).year(.twoDigits)) - \(transaction.amount) руб")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                }
                .sheet(item: $selectedTransacion) { transaction in
                    TransactionDetailView(transaction: transaction)
                }
            } else {
                ForEach(userTransactions.sorted { $0.date < $1.date} ) { transaction in
                    Button(action: {
                        selectedTransacion = transaction
                    }) {
                        Spacer()
                        Text("\(transaction.type.displayName) : \(transaction.date, format: .dateTime.day(.twoDigits).month(.twoDigits).year(.twoDigits)) - \(transaction.amount) руб")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                }
                .sheet(item: $selectedTransacion) { transaction in
                    TransactionDetailView(transaction: transaction)
                }
            }
            Spacer()
            
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
    @Environment(\.dismiss) private var dismiss
    
    let transaction: Transaction
    
    var body: some View {
        Text("Детали операции:")
        Text(transaction.type.displayName)
        Text(transaction.date, format: .dateTime.day(.twoDigits).month(.twoDigits).year(.twoDigits))
        Text("\(transaction.amount) руб.")
        if transaction.type == .income {
            Text("Пополнение баланса счета \(transaction.toAccount?.name ?? "неизвестно") с категории \(transaction.fromCategory?.name ?? "неизвестно")")
        } else if transaction.type == .expense {
            Text("Платёж со счета \(transaction.fromAccount?.name ?? "неизвестно") по категории \(transaction.toCategory?.name ?? "неизвестно")")
            } else {
                Text("Перевод со счета \(transaction.fromAccount?.name ?? "неизвестно") на счет \(transaction.toAccount?.name ?? "неизвестно")")
            }
        Button("Удалить операцию") {
            let service = TransactionService(context: context)
            service.dellTransaction(transaction)
            dismiss()
        }
        Button("Закрыть окно") {
            dismiss()
        }
    }
    
}
