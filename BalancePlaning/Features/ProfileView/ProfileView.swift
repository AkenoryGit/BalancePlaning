//
//  ProfileView.swift
//  BalancePlaning
//

import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var context
    @Binding var isLogged: Bool

    @State private var showAddAccountSheet: Bool = false
    @State private var showAddCategorySheet: Bool = false
    @State private var accountName: String = ""
    @State private var startBalance: String = ""
    @State private var type: CategoryType = .expense

    var userService: UserService { UserService(context: context) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // Карточка пользователя
                    if let user = userService.getCurrentUser() {
                        HStack(spacing: 14) {
                            // Аватар с первой буквой логина
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
                                    Text(String(user.login.prefix(1)).uppercased())
                                        .font(.title2.bold())
                                        .foregroundStyle(.white)
                                }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Аккаунт")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(user.login)
                                    .font(.headline)
                            }
                            Spacer()
                        }
                        .padding(16)
                        .cardStyle()
                        .padding(.horizontal)
                    }

                    // Счета
                    VStack(spacing: 8) {
                        ProfileSectionHeader(title: "Мои счета") {
                            showAddAccountSheet = true
                            accountName = ""
                            startBalance = ""
                        }
                        AccountsView()
                    }

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
                    .padding(.bottom, 32)
                }
                .padding(.top, 8)
            }
            .background(AppTheme.Colors.pageBackground)
            .navigationTitle("Профиль")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showAddAccountSheet) {
            AddAccountSheet(accountName: $accountName, startBalance: $startBalance)
        }
        .sheet(isPresented: $showAddCategorySheet) {
            AddCategorySheet(type: $type)
        }
    }
}

// MARK: - Заголовок секции с кнопкой "+"

struct ProfileSectionHeader: View {
    let title: String
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
