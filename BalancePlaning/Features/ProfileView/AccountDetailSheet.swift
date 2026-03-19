//
//  AccountDetailSheet.swift
//  BalancePlaning
//

import SwiftUI
import SwiftData

// MARK: - Детали и редактирование счёта

struct AccountDetailSheet: View {
    @Environment(\.modelContext) private var context
    let account: Account
    let groups: [AccountGroup]
    @Binding var selectedAccount: Account?

    @State private var name: String
    @State private var groupId: UUID?
    @State private var selectedIcon: String
    @State private var showCorrection = false
    @State private var nameError = false
    @State private var showDeleteDialog = false
    @State private var pendingAction: (() -> Void)?

    init(account: Account, groups: [AccountGroup], selectedAccount: Binding<Account?>) {
        self.account = account
        self.groups = groups
        self._selectedAccount = selectedAccount
        self._name = State(initialValue: account.name)
        self._groupId = State(initialValue: account.groupId)
        self._selectedIcon = State(initialValue: account.icon)
    }

    @Query private var allCurrencies: [Currency]

    private var userCurrencies: [Currency] {
        guard let uid = currentUserId() else { return [] }
        return allCurrencies.filter { $0.userId == uid }
    }

    private var accountService: AccountService { AccountService(context: context) }

    private var currentBalance: Decimal { accountService.currentBalance(for: account) }

    private var selectedGroupName: String {
        if let gid = groupId, let g = groups.first(where: { $0.id == gid }) { return g.name }
        return AppSettings.shared.bundle.localizedString(forKey: "Без группы", value: "Без группы", table: nil)
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHandle().padding(.bottom, 24)

            VStack(spacing: 6) {
                Image(systemName: selectedIcon.isEmpty ? "creditcard.fill" : selectedIcon)
                    .font(.system(size: 44))
                    .foregroundStyle(AppTheme.Colors.accent)

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(currentBalance, format: .number.precision(.fractionLength(0...2)))
                        .font(.title.bold())
                        .foregroundStyle(AppTheme.Colors.accent)
                    Text(CurrencyInfo.symbol(for: account.currency, custom: userCurrencies))
                        .font(.title3.bold())
                        .foregroundStyle(AppTheme.Colors.accent.opacity(0.8))
                }
            }
            .padding(.bottom, 24)

            VStack(spacing: 12) {
                // Имя
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 12) {
                        Image(systemName: "pencil").foregroundStyle(AppTheme.Colors.accent).frame(width: 20)
                        TextField("Название счёта", text: $name)
                            .onChange(of: name) { _, _ in nameError = false }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(nameError ? Color.red : Color.clear, lineWidth: 1.5))

                    if nameError {
                        Text("Введите название счёта")
                            .font(.caption).foregroundStyle(.red).padding(.leading, 4)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }

                // Валюта (только просмотр)
                let currInfo = CurrencyInfo.info(for: account.currency, custom: userCurrencies)
                HStack(spacing: 12) {
                    Image(systemName: "dollarsign.circle").foregroundStyle(AppTheme.Colors.accent).frame(width: 20)
                    Text("\(currInfo.symbol) \(currInfo.name)").foregroundStyle(.secondary)
                    Spacer()
                    Text(currInfo.code).font(.caption).foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Группа
                Menu {
                    Button("Без группы") { groupId = nil }
                    if !groups.isEmpty { Divider() }
                    ForEach(groups) { g in Button(g.name) { groupId = g.id } }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "folder").foregroundStyle(AppTheme.Colors.accent).frame(width: 20)
                        Text(selectedGroupName).foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

            }
            .padding(.horizontal)

            // Иконка — снаружи .padding(.horizontal) чтобы скролл шёл до краёв
            VStack(alignment: .leading, spacing: 6) {
                Text("Иконка")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                IconPickerView(selectedIcon: $selectedIcon,
                               icons: IconPalette.accountIcons,
                               accentColor: AppTheme.Colors.accent)
            }

            Spacer()

            VStack(spacing: 12) {
                PrimaryButton(title: "Сохранить", action: save)

                Button { showCorrection = true } label: {
                    Label("Скорректировать баланс", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered).tint(AppTheme.Colors.accent)

                Button(role: .destructive) {
                    showDeleteDialog = true
                } label: {
                    Label("Удалить счёт", systemImage: "trash").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered).tint(.red)
                .confirmationDialog("Удалить счёт «\(account.name)»?", isPresented: $showDeleteDialog, titleVisibility: .visible) {
                    Button("Удалить счёт и все операции", role: .destructive) {
                        pendingAction = { AccountService(context: context).deleteAccountWithTransactions(account) }
                        selectedAccount = nil
                    }
                    Button("Удалить счёт, операции — без счёта", role: .destructive) {
                        pendingAction = { AccountService(context: context).deleteAccountDetachingTransactions(account) }
                        selectedAccount = nil
                    }
                    Button("Отмена", role: .cancel) {}
                } message: {
                    Text("Выберите, что сделать с операциями, привязанными к этому счёту")
                }
            }
            .padding(.horizontal).padding(.bottom, 32)
        }
        .sheet(isPresented: $showCorrection) {
            BalanceCorrectionSheet(account: account, currentBalance: currentBalance)
        }
        .onDisappear { pendingAction?(); pendingAction = nil }
        .animation(.easeInOut(duration: 0.2), value: nameError)
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { nameError = true; return }
        account.name = trimmed
        account.groupId = groupId
        account.icon = selectedIcon
        try? context.save()
        selectedAccount = nil
    }
}

// MARK: - Корректировка баланса

struct BalanceCorrectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let account: Account
    let currentBalance: Decimal

    @State private var newBalanceString = ""
    @State private var comment = ""
    @State private var date = Date.now
    @State private var didAttemptApply = false

    private var newBalance: Decimal? {
        Decimal(string: newBalanceString.replacingOccurrences(of: ",", with: "."))
    }
    private var delta: Decimal? {
        guard let nb = newBalance else { return nil }
        return nb - currentBalance
    }
    private var isValid: Bool { newBalance != nil }

    var body: some View {
        VStack(spacing: 0) {
            SheetHandle().padding(.bottom, 20)

            Text("Корректировка баланса")
                .font(.title3.bold()).padding(.bottom, 4)
            Text(account.name)
                .font(.subheadline).foregroundStyle(.secondary).padding(.bottom, 20)

            HStack {
                Text("Текущий баланс").foregroundStyle(.secondary)
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(currentBalance, format: .number.precision(.fractionLength(0...2))).fontWeight(.medium)
                    Text(CurrencyInfo.symbol(for: account.currency)).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal).padding(.vertical, 10)

            Divider().padding(.horizontal)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundStyle(AppTheme.Colors.accent).frame(width: 20)
                    TextField("Новый баланс", text: $newBalanceString)
                        .keyboardType(.decimalPad)
                        .onChange(of: newBalanceString) { _, _ in if didAttemptApply { didAttemptApply = false } }
                    if let d = delta, d != 0 {
                        let sym = CurrencyInfo.symbol(for: account.currency)
                        (Text(d > 0 ? "+" : "−") +
                         Text(abs(d), format: .number.precision(.fractionLength(0...2))) +
                         Text(" \(sym)"))
                            .font(.caption.bold())
                            .foregroundStyle(d > 0 ? AppTheme.Colors.income : AppTheme.Colors.expense)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(didAttemptApply && !isValid ? Color.red : Color.clear, lineWidth: 1.5))

                if didAttemptApply && !isValid {
                    Text("Введите корректную сумму")
                        .font(.caption).foregroundStyle(.red).padding(.leading, 4)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal).padding(.top, 16)

            DatePicker("Дата корректировки", selection: $date, displayedComponents: [.date])
                .padding(.horizontal).padding(.top, 12)

            HStack(spacing: 12) {
                Image(systemName: "text.alignleft")
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                TextField("Комментарий (необязательно)", text: $comment)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal).padding(.top, 12)

            Spacer()

            PrimaryButton(title: "Применить") {
                didAttemptApply = true
                guard let d = delta, isValid, d != 0 else { return }
                TransactionService(context: context).addCorrection(account: account, delta: d, date: date, comment: comment)
                dismiss()
            }
            .padding(.horizontal).padding(.bottom, 32)
        }
        .presentationDetents([.medium, .large])
        .animation(.easeInOut(duration: 0.2), value: didAttemptApply)
    }
}
