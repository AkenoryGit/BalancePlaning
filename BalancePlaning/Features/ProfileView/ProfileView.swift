//
//  ProfileView.swift
//  BalancePlaning
//
//  Created by Дмитрий Дудник on 09.02.2026.
//

import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var context
    @Binding var isLogged: Bool

    @State private var showAddAccountSheet: Bool = false
    @State private var showAddCategorySheet: Bool = false
    @State private var accountName: String = ""
    @State private var categoryName: String = ""
    @State private var startBalance: String = ""
    @State private var type: CategoryType = .expense

    var userService: UserService {
        UserService(context: context)
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                Spacer(minLength: 250)
                AccountsView()

                Button("+ Добавить счёт") {
                    showAddAccountSheet = true
                    accountName = ""
                    startBalance = ""
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .padding(.horizontal)

                CategoriesView(isIncome: true)

                Button("+ Добавить категорию доходов") {
                    showAddCategorySheet = true
                    categoryName = ""
                    type = .income
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .padding(.horizontal)

                CategoriesView(isIncome: false)

                Button("+ Добавить категорию расходов") {
                    showAddCategorySheet = true
                    categoryName = ""
                    type = .expense
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .padding(.horizontal)

                Button("Выйти", role: .destructive) {
                    UserDefaults.standard.removeObject(forKey: UserDefaultKeys.currentUserId)
                    isLogged = false
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
            }
            .background(Color(.systemGroupedBackground))

            ZStack {
                Header(title: "Профиль", avatarSystemName: "person.fill", trailingAvatar: 0)
                    .frame(width: geometry.size.width, height: 250)
                VStack {
                    if let user = userService.getCurrentUser() {
                        Text(user.login)
                            .font(.title2)
                    } else {
                        Text("Пользователь не найден")
                            .foregroundStyle(.secondary)
                            .italic()
                    }
                }
                .padding(.top, 200)
            }
            .sheet(isPresented: $showAddAccountSheet) {
                AddAccountSheet(accountName: $accountName, startBalance: $startBalance)
            }
            .sheet(isPresented: $showAddCategorySheet) {
                AddCategorySheet(categoryName: $categoryName, type: $type)
            }
        }
    }
}
