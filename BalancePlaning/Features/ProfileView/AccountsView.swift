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
        VStack(spacing: 6) {
            ForEach(userAccounts) { account in
                Button {
                    selectedAccount = account
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "creditcard.fill")
                            .font(.title3)
                            .foregroundStyle(AppTheme.Colors.accent)
                            .frame(width: 40, height: 40)
                            .background(AppTheme.Colors.accent.opacity(0.1))
                            .clipShape(Circle())

                        Text(account.name)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Spacer()

                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(accountService.currentBalance(for: account),
                                 format: .number.precision(.fractionLength(0...2)))
                                .font(.subheadline.bold())
                                .foregroundStyle(AppTheme.Colors.accent)
                            Text("₽")
                                .font(.caption.bold())
                                .foregroundStyle(AppTheme.Colors.accent.opacity(0.8))
                        }
                    }
                    .padding(14)
                    .cardStyle()
                    .padding(.horizontal, 20)
                }
            }
        }
        .overlay {
            if userAccounts.isEmpty {
                ContentUnavailableView("Нет счетов", systemImage: "wallet.bifold")
                    .padding(.top, 20)
            }
        }
        .sheet(item: $selectedAccount) { item in
            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.secondary.opacity(0.4))
                    .frame(width: 40, height: 4)
                    .padding(.top, 12)
                    .padding(.bottom, 20)

                Image(systemName: "creditcard.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(AppTheme.Colors.accent)
                    .padding(.bottom, 8)

                Text(item.name)
                    .font(.title2.bold())

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(accountService.currentBalance(for: item),
                         format: .number.precision(.fractionLength(0...2)))
                        .font(.title.bold())
                        .foregroundStyle(AppTheme.Colors.accent)
                    Text("₽")
                        .font(.title3.bold())
                        .foregroundStyle(AppTheme.Colors.accent.opacity(0.8))
                }
                .padding(.top, 4)
                .padding(.bottom, 32)

                Button(role: .destructive) {
                    if let item = selectedAccount {
                        AccountService(context: context).deleteAccount(item)
                        selectedAccount = nil
                    }
                } label: {
                    Label("Удалить счёт", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .presentationDetents([.medium])
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
