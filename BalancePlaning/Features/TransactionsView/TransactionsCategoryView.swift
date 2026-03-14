//
//  TransactionsCategoryView.swift
//  BalancePlaning
//

import SwiftUI
import SwiftData

// MARK: - Выбор типа операции (Bottom Sheet)

struct TransactionsCategoryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var isTransactionPresented = false
    @State private var isExpensePresented = false
    @State private var isIncomePresented = false
    @State private var isLoanPaymentPresented = false

    @Binding var isRootPresented: Bool

    var transactionService: TransactionService { TransactionService(context: context) }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 40, height: 4)
                .padding(.top, 12)

            Text("Новая операция")
                .font(.title2.bold())
                .padding(.top, 16)
                .padding(.bottom, 20)

            VStack(spacing: 12) {
                TransactionTypeCard(
                    color: AppTheme.Colors.transfer,
                    icon: "arrow.left.arrow.right.circle.fill",
                    title: "Перевод",
                    subtitle: "Между вашими счетами"
                ) { isTransactionPresented = true }

                TransactionTypeCard(
                    color: AppTheme.Colors.expense,
                    icon: "minus.circle.fill",
                    title: "Расход",
                    subtitle: "Оплата, покупки, траты"
                ) { isExpensePresented = true }

                TransactionTypeCard(
                    color: AppTheme.Colors.income,
                    icon: "plus.circle.fill",
                    title: "Пополнение",
                    subtitle: "Доход, возврат средств"
                ) { isIncomePresented = true }

                TransactionTypeCard(
                    color: Color(hex: "E74C3C"),
                    icon: "creditcard.fill",
                    title: "Кредит",
                    subtitle: "Плановый или досрочный платёж"
                ) { isLoanPaymentPresented = true }
            }
            .padding(.horizontal)

            Button("Отмена") { dismiss() }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 20)
                .padding(.bottom, 24)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .sheet(isPresented: $isTransactionPresented) {
            AddTransactionView(isRootPresented: $isRootPresented, transactionService: transactionService)
        }
        .sheet(isPresented: $isExpensePresented) {
            AddExpenseView(isRootPresented: $isRootPresented, transactionService: transactionService)
        }
        .sheet(isPresented: $isIncomePresented) {
            AddIncomeView(isRootPresented: $isRootPresented, transactionService: transactionService)
        }
        .sheet(isPresented: $isLoanPaymentPresented) {
            LoanPaymentFromMainSheet(isRootPresented: $isRootPresented)
        }
    }
}

// MARK: - Карточка типа операции

struct TransactionTypeCard: View {
    let color: Color
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 50, height: 50)
                    .background(color.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline).foregroundStyle(.primary)
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .cardStyle()
        }
    }
}
