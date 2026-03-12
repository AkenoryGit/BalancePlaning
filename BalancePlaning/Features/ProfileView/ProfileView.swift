//
//  ProfileView.swift
//  BalancePlaning
//
//  Created by Дмитрий Дудник on 09.02.2026.
//

import SwiftUI
import SwiftData

struct ProfileView: View {
    // подключаемся к SwiftData через context
    @Environment(\.modelContext) private var context
    @Binding var isLogged: Bool
    
    @State private var showAddAccountSheet: Bool = false
    @State private var showAddCategorySheet: Bool = false
    @State private var accountName: String = ""
    @State private var categoryName: String = ""
    @State private var startBalance: String = ""
    @State private var type: CategoryType = .expense
    
    private var headView: Header
    private var accountsView: AccountsView
    private var incomeCategoriesView: CategoriesView
    private var expenseCategoriesView: CategoriesView
    
    // создаем экземпляр UserService для определения id текущего пользователя в дальнейшем
    var userService: UserService {
        UserService(context: context) }
    
    // инициализируем нужные параметры для хедера
    init(headView: Header, isLogged: Binding<Bool>, accountsView: AccountsView) {
        self.headView = headView
        self._isLogged = isLogged
        self.headView.avatarSystemName = "person.fill"
        self.headView.trailingAvatar = 0
        
        self.accountsView = accountsView
        self.incomeCategoriesView = CategoriesView(isIncome: true)
        self.expenseCategoriesView = CategoriesView(isIncome: false)
    }
    
    var body: some View {
        GeometryReader { geometry in
                ScrollView {
                    Spacer(minLength: 250)
                    accountsView
                    
                    Button("+ Добавить счёт") {
                        showAddAccountSheet = true
                        accountName = ""
                        startBalance = ""
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
                    
                    incomeCategoriesView
                    
                    Button("+ Добавить категорию доходов") {
                        showAddCategorySheet = true
                        categoryName = ""
                        type = CategoryType.income
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
                    
                    expenseCategoriesView
                    
                    Button("+ Добавить категорию расходов") {
                        showAddCategorySheet = true
                        categoryName = ""
                        type = CategoryType.expense
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
                    
                    // кнопка выхода из профиля пользователя и сброс id пользователя из UserDefaults
                    Button("Выйти", role: .destructive) {
                        UserDefaults.standard.removeObject(forKey: UserDefaultKeys.currentUserId)
                        isLogged = false
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
                }
                .padding(.top, 1)
                .background(Color(.systemGroupedBackground))
                .padding(.top, 1)
                ZStack {
                    headView
                        .frame(width: geometry.size.width, height: 250)
                    VStack {
                        // если все правильно с авторизацией пользотваеля, то отображаем его логин(почту) на экране
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
