//
//  ProfileView.swift
//  BalancePlaning
//

import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var context
    @Binding var isLogged: Bool
    @ObservedObject private var settings = AppSettings.shared

    @Query private var allCurrencies: [Currency]
    @Query private var allAccounts: [Account]
    @Query private var allLoans: [Loan]
    @State private var showAddCategorySheet: Bool = false
    @State private var showAddCurrencySheet: Bool = false
    @State private var showProfileDetail: Bool = false
    @State private var showSettings: Bool = false
    @State private var type: CategoryType = .expense
    @State private var currencyToDelete: Currency? = nil
    @State private var showCurrencyInUseAlert = false
    @State private var showCurrencyDeleteAlert = false

    var userService: UserService { UserService(context: context) }

    private var userCurrencies: [Currency] {
        guard let uid = currentUserId() else { return [] }
        return allCurrencies.filter { $0.userId == uid }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    HStack {
                        Text("Профиль")
                            .font(.largeTitle.bold())
                        Spacer()
                        Button { showSettings = true } label: {
                            Image(systemName: "gearshape")
                                .font(.title3)
                                .foregroundStyle(AppTheme.Colors.accent)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)

                    // Карточка пользователя (кликабельная)
                    if let user = userService.getCurrentUser() {
                        let visibleName = user.displayName.isEmpty ? user.login : user.displayName
                        let avatarLetter = String(visibleName.prefix(1)).uppercased()

                        Button { showProfileDetail = true } label: {
                            HStack(spacing: 14) {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [AppTheme.Colors.accent, AppTheme.Colors.accentSecondary],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 52, height: 52)
                                    .overlay {
                                        Text(avatarLetter)
                                            .font(.title2.bold())
                                            .foregroundStyle(.white)
                                    }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Аккаунт")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(visibleName)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(16)
                            .cardStyle()
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                    }

                    // Счета
                    AccountsView()

                    // Категории доходов
                    VStack(spacing: 8) {
                        ProfileSectionHeader(title: "Категории доходов") {
                            showAddCategorySheet = true
                            type = .income
                        }
                        CategoriesView(isIncome: true)
                    }

                    // Категории расходов
                    VStack(spacing: 8) {
                        ProfileSectionHeader(title: "Категории расходов") {
                            showAddCategorySheet = true
                            type = .expense
                        }
                        CategoriesView(isIncome: false)
                    }

                    // Мои валюты
                    VStack(spacing: 8) {
                        ProfileSectionHeader(title: "Мои валюты") {
                            showAddCurrencySheet = true
                        }
                        if userCurrencies.isEmpty {
                            Button { showAddCurrencySheet = true } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "plus.circle")
                                        .font(.title3)
                                        .foregroundStyle(AppTheme.Colors.accent)
                                        .frame(width: 40, height: 40)
                                        .background(AppTheme.Colors.accent.opacity(0.1))
                                        .clipShape(Circle())
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Добавить валюту")
                                            .font(.subheadline)
                                            .foregroundStyle(AppTheme.Colors.accent)
                                        Text("Доллар, евро, другие")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.horizontal, 14).padding(.vertical, 12)
                                .cardStyle()
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 20)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(userCurrencies.enumerated()), id: \.element.id) { index, currency in
                                    if index > 0 {
                                        Divider().padding(.leading, 60)
                                    }
                                    HStack(spacing: 12) {
                                        Text(currency.symbol)
                                            .font(.title3.bold())
                                            .foregroundStyle(AppTheme.Colors.accent)
                                            .frame(width: 40, height: 40)
                                            .background(AppTheme.Colors.accent.opacity(0.1))
                                            .clipShape(Circle())
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(currency.name).font(.subheadline)
                                            Text(currency.code).font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Button(role: .destructive) {
                                            currencyToDelete = currency
                                            if isCurrencyInUse(currency) {
                                                showCurrencyInUseAlert = true
                                            } else {
                                                showCurrencyDeleteAlert = true
                                            }
                                        } label: {
                                            Image(systemName: "trash").foregroundStyle(.red)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 14).padding(.vertical, 10)
                                }
                            }
                            .cardStyle()
                            .padding(.horizontal, 20)
                        }
                    }

                    // Семейный бюджет
                    VStack(spacing: 8) {
                        HStack {
                            Text("Семейный бюджет")
                                .font(.headline)
                                .padding(.leading, 20)
                            Spacer()
                        }
                        FamilyBudgetView()
                    }

                    // Кнопка выхода
                    Button(role: .destructive) {
                        UserDefaults.standard.removeObject(forKey: UserDefaultKeys.currentUserId)
                        isLogged = false
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Выйти из аккаунта")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .padding(.horizontal)
                    .padding(.bottom, 100)
                }
                .padding(.top, 8)
            }
            .refreshable {
                let bm = SharedBudgetManager.shared
                guard bm.isParticipant || bm.shareURL != nil else { return }
                await CloudKitAutoSyncManager.shared.syncNowAsync()
            }
            .background(AppTheme.Colors.pageBackground)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .padding(.top, 8)
        }
        .sheet(isPresented: $showAddCategorySheet) {
            AddCategorySheet(type: $type)
        }
        .sheet(isPresented: $showAddCurrencySheet) {
            AddCurrencySheet()
        }
        .sheet(isPresented: $showProfileDetail) {
            if let user = userService.getCurrentUser() {
                ProfileDetailSheet(user: user)
            }
        }
        .sheet(isPresented: $showSettings) {
            AppSettingsSheet()
        }
        .alert("Валюта используется", isPresented: $showCurrencyInUseAlert) {
            Button("Понятно", role: .cancel) { currencyToDelete = nil }
        } message: {
            if let c = currencyToDelete {
                Text("Валюта \(c.name) (\(c.code)) используется в счетах или кредитах. Удалите или переведите их на другую валюту, прежде чем удалить эту валюту.")
            }
        }
        .alert("Удалить валюту?", isPresented: $showCurrencyDeleteAlert) {
            Button("Удалить", role: .destructive) {
                if let c = currencyToDelete { CurrencyService(context: context).deleteCurrency(c) }
                currencyToDelete = nil
            }
            Button("Отмена", role: .cancel) { currencyToDelete = nil }
        } message: {
            if let c = currencyToDelete {
                Text("Валюта \(c.name) (\(c.code)) будет удалена безвозвратно.")
            }
        }
    }

    private func isCurrencyInUse(_ currency: Currency) -> Bool {
        let code = currency.code
        let accountUsed = allAccounts.contains { $0.currency == code }
        let loanUsed = allLoans.contains { $0.currency == code }
        return accountUsed || loanUsed
    }
}

// MARK: - Заголовок секции с кнопкой "+"

struct ProfileSectionHeader: View {
    let title: LocalizedStringKey
    let onAdd: () -> Void

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .padding(.leading, 20)
            Spacer()
            Button(action: onAdd) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.caption.bold())
                    Text("Добавить")
                        .font(.subheadline)
                }
                .foregroundStyle(AppTheme.Colors.accent)
            }
            .padding(.trailing, 20)
        }
    }
}
