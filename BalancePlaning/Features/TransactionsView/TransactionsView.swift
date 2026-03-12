//
//  TransactionsView.swift
//  BalancePlaning
//

import SwiftUI
import SwiftData

// MARK: - Главный экран (Dashboard)

struct TransactionsView: View {
    @Environment(\.modelContext) var context
    @State private var date: Date = Date.now
    @State private var isPresented: Bool = false
    @State private var showDatePicker: Bool = false
    @State private var showAllTransactions: Bool = false
    @State private var selectedTransaction: Transaction?

    @Query private var allTransactions: [Transaction]

    private var userTransactions: [Transaction] {
        guard let userId = currentUserId() else { return [] }
        return allTransactions.filter { $0.userId == userId }
    }

    private var dailyTransactions: [Transaction] {
        userTransactions
            .filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.date > $1.date }
    }

    private var shownTransactions: [Transaction] {
        showAllTransactions
            ? userTransactions.sorted { $0.date > $1.date }
            : dailyTransactions
    }

    private var dailyIncome: Decimal {
        dailyTransactions.filter { $0.type == .income }.reduce(.zero) { $0 + $1.amount }
    }

    private var dailyExpense: Decimal {
        dailyTransactions.filter { $0.type == .expense }.reduce(.zero) { $0 + $1.amount }
    }

    private var accountService: AccountService { AccountService(context: context) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    // Карточка баланса
                    BalanceCard(
                        balance: accountService.totalBalance(at: date),
                        date: $date,
                        showAll: $showAllTransactions,
                        onDateTap: { showDatePicker = true }
                    )
                    .padding(.horizontal)

                    // Итоги за день (только в режиме «за день»)
                    if !showAllTransactions {
                        HStack(spacing: 12) {
                            SummaryPill(label: "Доходы", amount: dailyIncome, color: AppTheme.Colors.income)
                            SummaryPill(label: "Расходы", amount: dailyExpense, color: AppTheme.Colors.expense)
                        }
                        .padding(.horizontal)
                    }

                    // Переключатель режима
                    Picker("", selection: $showAllTransactions) {
                        Text("За день").tag(false)
                        Text("Все операции").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Список транзакций
                    if shownTransactions.isEmpty {
                        EmptyTransactionsPlaceholder(showAll: showAllTransactions)
                            .padding(.top, 40)
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(shownTransactions) { transaction in
                                TransactionCard(transaction: transaction)
                                    .padding(.horizontal)
                                    .onTapGesture { selectedTransaction = transaction }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            TransactionService(context: context)
                                                .deleteTransaction(transaction)
                                        } label: {
                                            Label("Удалить", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
            .background(AppTheme.Colors.pageBackground)
            .navigationTitle("Главная")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresented = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(AppTheme.Colors.accent)
                    }
                }
            }
        }
        .sheet(isPresented: $isPresented) {
            TransactionsCategoryView(isRootPresented: $isPresented)
        }
        .sheet(item: $selectedTransaction) { transaction in
            TransactionDetailView(transaction: transaction, selectedTransaction: $selectedTransaction)
        }
        .sheet(isPresented: $showDatePicker) {
            DatePickerSheet(date: $date, showAll: $showAllTransactions)
        }
    }
}

// MARK: - Карточка баланса (градиентная)

struct BalanceCard: View {
    let balance: Decimal
    @Binding var date: Date
    @Binding var showAll: Bool
    let onDateTap: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("Общий баланс")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(balance, format: .number.precision(.fractionLength(0...2)))
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(.white)
                Text("₽")
                    .font(.title2.bold())
                    .foregroundStyle(.white.opacity(0.85))
            }

            if !showAll {
                HStack(spacing: 10) {
                    // Кнопка ← день
                    Button {
                        date = Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(.white.opacity(0.2))
                            .clipShape(Circle())
                    }

                    // Кнопка с датой → открывает DatePicker
                    Button(action: onDateTap) {
                        Text(date.formatted(.dateTime
                            .locale(Locale(identifier: "ru_RU"))
                            .day(.defaultDigits)
                            .month(.wide)
                            .year(.defaultDigits)
                        ))
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(.white.opacity(0.2))
                        .clipShape(Capsule())
                    }

                    // Кнопка → день
                    Button {
                        date = Calendar.current.date(byAdding: .day, value: +1, to: date) ?? date
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [AppTheme.Colors.accent, AppTheme.Colors.accentSecondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: AppTheme.Colors.accent.opacity(0.4), radius: 12, x: 0, y: 6)
    }
}

// MARK: - Карточка транзакции

struct TransactionCard: View {
    let transaction: Transaction

    private var title: String {
        switch transaction.type {
        case .income:      return transaction.fromCategory?.name ?? "Пополнение"
        case .expense:     return transaction.toCategory?.name ?? "Расход"
        case .transaction: return "Перевод"
        }
    }

    private var subtitle: String {
        switch transaction.type {
        case .income:      return transaction.toAccount?.name ?? ""
        case .expense:     return transaction.fromAccount?.name ?? ""
        case .transaction:
            let from = transaction.fromAccount?.name ?? "?"
            let to   = transaction.toAccount?.name ?? "?"
            return "\(from) → \(to)"
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            // Иконка типа
            Image(systemName: transaction.type.icon)
                .font(.title3)
                .foregroundStyle(transaction.type.color)
                .frame(width: 44, height: 44)
                .background(transaction.type.color.opacity(0.12))
                .clipShape(Circle())

            // Название и счёт
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Сумма и время
            VStack(alignment: .trailing, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    if !transaction.type.amountPrefix.isEmpty {
                        Text(transaction.type.amountPrefix)
                            .font(.subheadline.bold())
                    }
                    Text(transaction.amount, format: .number.precision(.fractionLength(0...2)))
                        .font(.subheadline.bold())
                    Text("₽")
                        .font(.caption.bold())
                }
                .foregroundStyle(transaction.type.color)

                Text(transaction.date, format: .dateTime
                    .hour(.defaultDigits(amPM: .omitted))
                    .minute()
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .cardStyle()
    }
}

// MARK: - DatePicker Sheet

struct DatePickerSheet: View {
    @Binding var date: Date
    @Binding var showAll: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 40, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 8)

            DatePicker("", selection: $date, displayedComponents: [.date])
                .datePickerStyle(.graphical)
                .environment(\.locale, Locale(identifier: "ru_RU"))
                .padding(.horizontal)

            Button {
                showAll = true
                dismiss()
            } label: {
                Text("Показать все операции")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Empty State

struct EmptyTransactionsPlaceholder: View {
    let showAll: Bool

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 52))
                .foregroundStyle(.quaternary)
            Text(showAll ? "Операций ещё нет" : "Операций за этот день нет")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Нажмите + чтобы добавить первую операцию")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - Детали транзакции

struct TransactionDetailView: View {
    @Environment(\.modelContext) private var context
    let transaction: Transaction
    @Binding var selectedTransaction: Transaction?

    @State private var showEdit: Bool = false
    @State private var showDeleteAlert: Bool = false
    @State private var editWasSaved: Bool = false
    @State private var pendingAction: (() -> Void)?

    private var title: String {
        switch transaction.type {
        case .income:      return transaction.fromCategory?.name ?? "Пополнение"
        case .expense:     return transaction.toCategory?.name ?? "Расход"
        case .transaction: return "Перевод"
        }
    }

    var body: some View {
        VStack(spacing: 0) {

            // Шапка
            VStack(spacing: 8) {
                Image(systemName: transaction.type.icon)
                    .font(.system(size: 48))
                    .foregroundStyle(transaction.type.color)
                    .padding(.top, 32)

                Text(title)
                    .font(.title2.bold())

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    if !transaction.type.amountPrefix.isEmpty {
                        Text(transaction.type.amountPrefix)
                            .font(.system(size: 28, weight: .bold))
                    }
                    Text(transaction.amount, format: .number.precision(.fractionLength(0...2)))
                        .font(.system(size: 32, weight: .bold))
                    Text("₽")
                        .font(.title2.bold())
                }
                .foregroundStyle(transaction.type.color)

                Text(transaction.date, format: .dateTime
                    .locale(Locale(identifier: "ru_RU"))
                    .day().month(.wide).year()
                    .hour().minute()
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 20)
            }

            Divider()

            // Строки с деталями
            VStack(spacing: 0) {
                if transaction.type == .income {
                    DetailRow(label: "На счёт",    value: transaction.toAccount?.name ?? "—")
                    DetailRow(label: "Категория",  value: transaction.fromCategory?.name ?? "—")
                } else if transaction.type == .expense {
                    DetailRow(label: "Со счёта",   value: transaction.fromAccount?.name ?? "—")
                    DetailRow(label: "Категория",  value: transaction.toCategory?.name ?? "—")
                } else {
                    DetailRow(label: "Со счёта",   value: transaction.fromAccount?.name ?? "—")
                    DetailRow(label: "На счёт",    value: transaction.toAccount?.name ?? "—")
                }
                if transaction.recurringGroupId != nil {
                    DetailRow(label: "Тип", value: "Повторяющаяся")
                }
            }
            .padding(.horizontal)

            Spacer()

            // Кнопки
            VStack(spacing: 12) {
                Button {
                    editWasSaved = false
                    showEdit = true
                } label: {
                    Label("Редактировать", systemImage: "pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.Colors.accent)

                Button(role: .destructive) {
                    if transaction.recurringGroupId != nil {
                        showDeleteAlert = true
                    } else {
                        let service = TransactionService(context: context)
                        pendingAction = { service.deleteTransaction(transaction) }
                        selectedTransaction = nil
                    }
                } label: {
                    Label("Удалить операцию", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
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
        .onChange(of: showEdit) { _, isShowing in
            if !isShowing && editWasSaved {
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
        .onDisappear {
            pendingAction?()
            pendingAction = nil
        }
    }
}

// MARK: - Строка деталей

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .fontWeight(.medium)
            }
            .padding(.vertical, 13)
            Divider()
        }
    }
}
