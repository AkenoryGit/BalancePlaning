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
