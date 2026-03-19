//
//  FilterSheet.swift
//  BalancePlaning
//

import SwiftUI
import SwiftData

// MARK: - Режим отображения транзакций

enum TransactionViewMode: Int, CaseIterable {
    case day, all, period

    var label: String {
        switch self {
        case .day:    return "За день"
        case .all:    return "Все"
        case .period: return "За период"
        }
    }
}

// MARK: - Модель фильтра

struct TransactionFilter: Equatable {
    var startDate: Date = {
        let cal = Calendar.current
        return cal.date(from: cal.dateComponents([.year, .month], from: Date()))!
    }()
    var endDate: Date = Calendar.current.startOfDay(for: Date())
    var types: Set<TransactionType> = []
    var accountIds: Set<UUID> = []
    var categoryIds: Set<UUID> = []
    var minAmount: String = ""
    var maxAmount: String = ""
    var currencies: Set<String> = []

    var activeFilterCount: Int {
        [!types.isEmpty, !accountIds.isEmpty, !categoryIds.isEmpty,
         !minAmount.isEmpty || !maxAmount.isEmpty, !currencies.isEmpty]
            .filter { $0 }.count
    }

    func matches(_ t: Transaction) -> Bool {
        let cal = Calendar.current
        let endBound = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: endDate))!
        guard t.date >= startDate && t.date < endBound else { return false }

        if !types.isEmpty, !types.contains(t.type) { return false }

        if !accountIds.isEmpty {
            let ids = [t.fromAccount?.id, t.toAccount?.id].compactMap { $0 }
            guard ids.contains(where: { accountIds.contains($0) }) else { return false }
        }

        if !categoryIds.isEmpty {
            let ids = [t.fromCategory?.id, t.toCategory?.id].compactMap { $0 }
            guard ids.contains(where: { categoryIds.contains($0) }) else { return false }
        }

        if !minAmount.isEmpty,
           let min = Decimal(string: minAmount.replacingOccurrences(of: ",", with: ".")) {
            guard t.amount >= min else { return false }
        }
        if !maxAmount.isEmpty,
           let max = Decimal(string: maxAmount.replacingOccurrences(of: ",", with: ".")) {
            guard t.amount <= max else { return false }
        }

        if !currencies.isEmpty {
            let c = t.fromAccount?.currency ?? t.toAccount?.currency ?? "RUB"
            guard currencies.contains(c) else { return false }
        }

        return true
    }
}

// MARK: - Шит фильтров

struct FilterSheet: View {
    @Binding var filter: TransactionFilter
    @Environment(\.dismiss) private var dismiss

    @Query private var allAccounts: [Account]
    @Query private var allCategories: [Category]
    @Query private var allCurrencies: [Currency]

    @State private var draft: TransactionFilter

    init(filter: Binding<TransactionFilter>) {
        self._filter = filter
        self._draft = State(initialValue: filter.wrappedValue)
    }

    private var userAccounts: [Account] {
        guard let uid = currentUserId() else { return [] }
        return allAccounts.filter { $0.userId == uid }.sorted { $0.name < $1.name }
    }
    private var userCategories: [Category] {
        guard let uid = currentUserId() else { return [] }
        return CategoryService.sortedTree(from: allCategories.filter { $0.userId == uid })
    }
    private var userCurrencies: [Currency] {
        guard let uid = currentUserId() else { return [] }
        return allCurrencies.filter { $0.userId == uid }
    }
    private var availableCurrencies: [String] {
        let codes = Set(userAccounts.map { $0.currency })
        return codes.sorted { a, b in
            let ia = CurrencyInfo.predefined.firstIndex { $0.code == a } ?? 99
            let ib = CurrencyInfo.predefined.firstIndex { $0.code == b } ?? 99
            return ia == ib ? a < b : ia < ib
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // Период
                Section("Период") {
                    DatePicker("Начало", selection: $draft.startDate,
                               displayedComponents: [.date])
                    DatePicker("Конец", selection: $draft.endDate,
                               in: draft.startDate...,
                               displayedComponents: [.date])
                }

                // Тип операции
                Section("Тип операции") {
                    ForEach([TransactionType.income, .expense, .transaction, .correction],
                            id: \.self) { type in
                        Toggle(isOn: Binding(
                            get: { draft.types.contains(type) },
                            set: { on in if on { draft.types.insert(type) } else { draft.types.remove(type) } }
                        )) {
                            Label(LocalizedStringKey(type.displayName), systemImage: type.icon)
                                .foregroundStyle(type.color)
                        }
                        .tint(type.color)
                    }
                }

                // Счёт
                if !userAccounts.isEmpty {
                    Section("Счёт") {
                        ForEach(userAccounts) { acc in
                            Toggle(isOn: Binding(
                                get: { draft.accountIds.contains(acc.id) },
                                set: { on in if on { draft.accountIds.insert(acc.id) } else { draft.accountIds.remove(acc.id) } }
                            )) { Text(acc.name) }
                            .tint(AppTheme.Colors.accent)
                        }
                    }
                }

                // Категория
                if !userCategories.isEmpty {
                    Section("Категория") {
                        ForEach(userCategories) { cat in
                            Toggle(isOn: Binding(
                                get: { draft.categoryIds.contains(cat.id) },
                                set: { on in if on { draft.categoryIds.insert(cat.id) } else { draft.categoryIds.remove(cat.id) } }
                            )) {
                                Text(CategoryService.displayLabel(for: cat))
                                    .font(cat.isRoot ? .body : .subheadline)
                            }
                            .tint(AppTheme.Colors.accent)
                        }
                    }
                }

                // Сумма
                Section("Сумма") {
                    HStack {
                        Text("От")
                        Spacer()
                        TextField("0", text: $draft.minAmount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 110)
                    }
                    HStack {
                        Text("До")
                        Spacer()
                        TextField("∞", text: $draft.maxAmount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 110)
                    }
                }

                // Валюта
                if availableCurrencies.count > 1 {
                    Section("Валюта") {
                        ForEach(availableCurrencies, id: \.self) { code in
                            Toggle(isOn: Binding(
                                get: { draft.currencies.contains(code) },
                                set: { on in if on { draft.currencies.insert(code) } else { draft.currencies.remove(code) } }
                            )) {
                                Text("\(CurrencyInfo.symbol(for: code, custom: userCurrencies))  \(code)")
                            }
                            .tint(AppTheme.Colors.accent)
                        }
                    }
                }
            }
            .navigationTitle("Фильтры")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Сбросить") {
                        filter = TransactionFilter()
                        dismiss()
                    }
                    .foregroundStyle(AppTheme.Colors.expense)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Применить") {
                        filter = draft
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.Colors.accent)
                }
            }
        }
    }
}
