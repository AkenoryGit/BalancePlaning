//
//  AccountsView.swift
//  BalancePlaning
//
//  Created by Дмитрий Дудник on 26.02.2026.
//

import SwiftUI
import SwiftData

struct AccountsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Account.name) private var allAccounts: [Account]
    
    @State var selectedAccount: Account?
    @State private var date: Date = Date.now

    private var accountService: AccountService {
        AccountService(context: context)
    }
    
    private var userAccounts: [Account] {
        guard let userId = currentUserId() else {
            return []
        }
        return allAccounts.filter { $0.userId == userId }
    }
    
    var body: some View {
        VStack (spacing: 4){
            Text("Мои счета")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.horizontal)
            ForEach(userAccounts) { account in
                Button {
                    selectedAccount = account
                } label: {
                    HStack {
                        Text(account.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .padding(.leading, 40)
                        
                        Spacer()
                        
                        Text(accountService.currentBalance(for: account),
                             format: .number.precision(.fractionLength(0...2)))
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundStyle(.blue)
                            .padding(.trailing, 20)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                .padding(.trailing, 20)
                .padding(.leading, 20)
            }
        }
            .overlay {
                if userAccounts.isEmpty {
                    ContentUnavailableView("Нет счетов", systemImage: "wallet.bifold")
                }
            }
            .sheet(item: $selectedAccount) { item in
                VStack(spacing: 16) {
                    Text("Счёт")
                        .font(.headline)
                    Text(item.name)
                        .font(.largeTitle)
                        .bold()
                    Text("Баланс")
                        .font(.headline)
                    Text(item.balance, format: .number.precision(.fractionLength(0...2)))
                        .font(.title2)
                        .foregroundStyle(.blue)
                    Button("Удалить счёт", role: .destructive) {
                        if let item = selectedAccount {
                            let service = AccountService(context: context)
                            service.dellAccount(item)
                            selectedAccount = nil
                        }
                    }
                }
                .padding()
            }
        }
    }

struct AddAccountSheet: View {
    @Binding var accountName: String
    @Binding var startBalance: String
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Новый счёт")
                    .font(.title2.bold())
                
                TextField("Название счёта", text: $accountName)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                
                TextField("Начальный баланс", text: $startBalance)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
                    .padding(.horizontal)
                
                Button("Добавить") {
                    guard let balance = Decimal(string: startBalance.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                        print("Некорректный баланс")
                        return
                    }
                    let service = AccountService(context: context)
                    service.addAccount(accountName: accountName, startBalance: balance)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                
                Button("Отменить", role: .cancel) {
                    dismiss()
                }
            }
            .padding()
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}
