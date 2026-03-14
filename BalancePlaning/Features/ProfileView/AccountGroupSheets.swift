//
//  AccountGroupSheets.swift
//  BalancePlaning
//

import SwiftUI
import SwiftData

// MARK: - Добавление счёта

struct AddAccountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query private var allCurrencies: [Currency]

    let groups: [AccountGroup]

    @State private var name = ""
    @State private var balanceString = ""
    @State private var groupId: UUID? = nil
    @State private var currency = "RUB"
    @State private var didAttemptSave = false
    @State private var showAddCurrency = false

    private var userCurrencies: [Currency] {
        guard let uid = currentUserId() else { return [] }
        return allCurrencies.filter { $0.userId == uid }
    }

    private var nameIsValid: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var balance: Decimal? {
        balanceString.isEmpty ? .zero : Decimal(string: balanceString.replacingOccurrences(of: ",", with: "."))
    }
    private var balanceIsValid: Bool { balance != nil }
    private var selectedGroupName: String {
        if let gid = groupId, let g = groups.first(where: { $0.id == gid }) { return g.name }
        return "Без группы"
    }
    private var allCurrencyOptions: [CurrencyInfo] { CurrencyInfo.all(custom: userCurrencies) }
    private var selectedCurrencyLabel: String {
        let info = CurrencyInfo.info(for: currency, custom: userCurrencies)
        return "\(info.symbol) \(info.name)"
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHandle().padding(.bottom, 24)

            Text("Новый счёт").font(.title3.bold()).padding(.bottom, 24)

            VStack(spacing: 12) {
                inputField(icon: "creditcard.fill", placeholder: "Название счёта", text: $name,
                           hasError: didAttemptSave && !nameIsValid, errorText: "Введите название счёта",
                           keyboard: .default)
                    .onChange(of: name) { _, _ in if didAttemptSave { didAttemptSave = false } }

                inputField(icon: "banknote", placeholder: "Начальный баланс (необязательно)",
                           text: $balanceString,
                           hasError: didAttemptSave && !balanceIsValid, errorText: "Введите корректную сумму",
                           keyboard: .decimalPad)
                    .onChange(of: balanceString) { _, _ in if didAttemptSave { didAttemptSave = false } }

                currencyPicker

                if !groups.isEmpty {
                    groupPicker
                }
            }
            .padding(.horizontal)

            Spacer()

            VStack(spacing: 12) {
                PrimaryButton(title: "Добавить") {
                    didAttemptSave = true
                    guard nameIsValid && balanceIsValid else { return }
                    AccountService(context: context).addAccount(
                        accountName: name.trimmingCharacters(in: .whitespacesAndNewlines),
                        startBalance: balance ?? .zero,
                        groupId: groupId,
                        currency: currency
                    )
                    dismiss()
                }
                Button("Отменить", role: .cancel) { dismiss() }.foregroundStyle(.secondary)
            }
            .padding(.horizontal).padding(.bottom, 32)
        }
        .presentationDetents([.medium, .large])
        .animation(.easeInOut(duration: 0.2), value: didAttemptSave)
        .sheet(isPresented: $showAddCurrency) {
            AddCurrencySheet()
        }
    }

    private var currencyPicker: some View {
        Menu {
            ForEach(allCurrencyOptions) { info in
                Button { currency = info.code } label: {
                    Text("\(info.symbol) \(info.name)")
                }
            }
            Divider()
            Button { showAddCurrency = true } label: {
                Label("Добавить свою валюту", systemImage: "plus")
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "dollarsign.circle").foregroundStyle(AppTheme.Colors.accent).frame(width: 20)
                Text(selectedCurrencyLabel).foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var groupPicker: some View {
        Menu {
            Button("Без группы") { groupId = nil }
            Divider()
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
}

// MARK: - Добавление пользовательской валюты

struct AddCurrencySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var code = ""
    @State private var symbol = ""
    @State private var name = ""
    @State private var didAttemptSave = false

    private var codeIsValid:   Bool { !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var symbolIsValid: Bool { !symbol.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var nameIsValid:   Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            SheetHandle().padding(.bottom, 24)

            Text("Новая валюта").font(.title3.bold()).padding(.bottom, 24)

            VStack(spacing: 12) {
                inputField(icon: "textformat.abc", placeholder: "Код (напр. MEME)", text: $code,
                           hasError: didAttemptSave && !codeIsValid, errorText: "Введите код валюты",
                           keyboard: .default)
                inputField(icon: "dollarsign.circle", placeholder: "Символ (напр. M)", text: $symbol,
                           hasError: didAttemptSave && !symbolIsValid, errorText: "Введите символ",
                           keyboard: .default)
                inputField(icon: "tag", placeholder: "Название (напр. Memecoin)", text: $name,
                           hasError: didAttemptSave && !nameIsValid, errorText: "Введите название",
                           keyboard: .default)
            }
            .padding(.horizontal)

            Spacer()

            VStack(spacing: 12) {
                PrimaryButton(title: "Добавить") {
                    didAttemptSave = true
                    guard codeIsValid && symbolIsValid && nameIsValid else { return }
                    CurrencyService(context: context).addCurrency(
                        code: code.trimmingCharacters(in: .whitespacesAndNewlines),
                        symbol: symbol.trimmingCharacters(in: .whitespacesAndNewlines),
                        name: name.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                    dismiss()
                }
                Button("Отменить", role: .cancel) { dismiss() }.foregroundStyle(.secondary)
            }
            .padding(.horizontal).padding(.bottom, 32)
        }
        .presentationDetents([.medium, .large])
        .animation(.easeInOut(duration: 0.2), value: didAttemptSave)
    }
}

// MARK: - Добавление группы

struct AddGroupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var name = ""
    @State private var nameError = false

    var body: some View {
        VStack(spacing: 0) {
            SheetHandle().padding(.bottom, 24)

            Text("Новая группа").font(.title3.bold()).padding(.bottom, 24)

            inputField(icon: "folder.fill", placeholder: "Название группы", text: $name,
                       hasError: nameError, errorText: "Введите название группы", keyboard: .default)
                .onChange(of: name) { _, _ in nameError = false }
                .padding(.horizontal)

            Spacer()

            VStack(spacing: 12) {
                PrimaryButton(title: "Создать") {
                    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { nameError = true; return }
                    AccountGroupService(context: context).addGroup(name: trimmed)
                    dismiss()
                }
                Button("Отменить", role: .cancel) { dismiss() }.foregroundStyle(.secondary)
            }
            .padding(.horizontal).padding(.bottom, 32)
        }
        .presentationDetents([.medium])
        .animation(.easeInOut(duration: 0.2), value: nameError)
    }
}

// MARK: - Редактирование / удаление группы

struct GroupDetailSheet: View {
    @Environment(\.modelContext) private var context
    let group: AccountGroup
    @Binding var selectedGroup: AccountGroup?

    @State private var name: String
    @State private var nameError = false
    @State private var showDeleteAlert = false
    @State private var pendingAction: (() -> Void)?

    init(group: AccountGroup, selectedGroup: Binding<AccountGroup?>) {
        self.group = group
        self._selectedGroup = selectedGroup
        self._name = State(initialValue: group.name)
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHandle().padding(.bottom, 24)

            Text("Группа счетов").font(.title3.bold()).padding(.bottom, 24)

            inputField(icon: "folder.fill", placeholder: "Название группы", text: $name,
                       hasError: nameError, errorText: "Введите название группы", keyboard: .default)
                .onChange(of: name) { _, _ in nameError = false }
                .padding(.horizontal)

            Spacer()

            VStack(spacing: 12) {
                PrimaryButton(title: "Сохранить") {
                    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { nameError = true; return }
                    AccountGroupService(context: context).updateGroup(group, name: trimmed)
                    selectedGroup = nil
                }
                Button(role: .destructive) { showDeleteAlert = true } label: {
                    Label("Удалить группу", systemImage: "trash").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered).tint(.red)
            }
            .padding(.horizontal).padding(.bottom, 32)
        }
        .alert("Удалить группу?", isPresented: $showDeleteAlert) {
            Button("Удалить", role: .destructive) {
                pendingAction = { AccountGroupService(context: context).deleteGroup(group) }
                selectedGroup = nil
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Счета из группы станут «Без группы»")
        }
        .onDisappear { pendingAction?(); pendingAction = nil }
        .presentationDetents([.medium, .large])
        .animation(.easeInOut(duration: 0.2), value: nameError)
    }
}

// MARK: - Общий компонент текстового поля для шитов

private func inputField(
    icon: String,
    placeholder: String,
    text: Binding<String>,
    hasError: Bool,
    errorText: String,
    keyboard: UIKeyboardType
) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(AppTheme.Colors.accent).frame(width: 20)
            TextField(placeholder, text: text).keyboardType(keyboard)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12)
            .strokeBorder(hasError ? Color.red : Color.clear, lineWidth: 1.5))

        if hasError {
            Text(errorText)
                .font(.caption).foregroundStyle(.red).padding(.leading, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}
