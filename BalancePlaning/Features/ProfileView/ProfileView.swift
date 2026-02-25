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
    @State private var startBalance: String = "0"
    @State private var type: CategoryType = .expense
    @State private var selectedAccount: Account? = nil
    @State private var selectedCategory: Category? = nil
    
    @Query(sort: \Account.name) private var allAccounts: [Account]
    @Query(sort: \Category.name) private var allCategories: [Category]
    
    private var userAccounts: [Account] {
        guard let userIdString = UserDefaults.standard.string(forKey: UserDefaultKeys.currentUserId),
              let userId = UUID(uuidString: userIdString) else {
            return []
        }
        return allAccounts.filter { $0.userId == userId }
    }
    
    private var userCategories: [Category] {
        guard let userIdString = UserDefaults.standard.string(forKey: UserDefaultKeys.currentUserId),
              let userId = UUID(uuidString: userIdString) else {
            return []
        }
        return allCategories.filter { $0.userId == userId }
    }
    private var expenseCategories: [Category] {
        userCategories.filter { $0.type == .expense }
    }
    private var incomeCategories: [Category] {
        userCategories.filter { $0.type == .income }
    }
    
    private var headView: Header
    
    // создаем экземпляр UserService для определения id текущего пользователя в дальнейшем
    var userService: UserService {
        UserService(context: context) }
    
    // инициализируем нужные параметры для хедера
    init(headView: Header, isLogged: Binding<Bool>) {
        self.headView = headView
        self._isLogged = isLogged
        self.headView.avatarSystemName = "person.fill"
        self.headView.trailingAvatar = 0
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
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
                Spacer()
                VStack (spacing: 4){
                    Text("Мои счета")
                        .font(.title2)
                        .background(Color(.systemGroupedBackground))
                    List(userAccounts) { account in
                            Button(action: {
                                selectedAccount = account
                            }) {
                                HStack {
                                    Text(account.name)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text(account.balance, format: .number.precision(.fractionLength(0...2)))
                                        .foregroundStyle(.secondary)
                                        .font(.subheadline)
                                }
                            }
                        }
                    .overlay {
                        if userAccounts.isEmpty {
                            ContentUnavailableView("Нет счетов", systemImage: "wallet.bifold")
                        }
                    }
                    .sheet(item: $selectedAccount) { item in
                        VStack(spacing: 16) {
                            Text("Счёт")
                                .font(.headline)
                            Text(item.name)
                                .font(.largeTitle)
                                .bold()
                            Text("Баланс")
                                .font(.headline)
                            Text(item.balance, format: .number.precision(.fractionLength(0...2)))
                                .font(.title2)
                                .foregroundStyle(.blue)
                            Button("Удалить счёт", role: .destructive) {
                                if let item = selectedAccount {
                                    let service = AccountService(context: context)
                                    service.dellAccount(item)
                                    selectedAccount = nil
                                }
                            }
                        }
                        .padding()
                    }
                    
                    Button("+ Добавить счёт") {
                        showAddAccountSheet = true
                        accountName = ""
                        startBalance = "0"
                    }
                }
                .background(Color(.systemGroupedBackground))
                
                VStack {
                    Text("Категории доходов")
                        .font(.title2)
                        .background(Color(.systemGroupedBackground))
                    List(incomeCategories) { category in
                            Button(action: {
                                selectedCategory = category
                            }) {
                                HStack {
                                    Text(category.name)
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                    .overlay {
                        if incomeCategories.isEmpty {
                            ContentUnavailableView("Нет категорий", systemImage: "bag.badge.minus")
                        }
                    }
                    .sheet(item: $selectedCategory) { item in
                        VStack(spacing: 16) {
                            Text("Категория")
                                .font(.headline)
                            Text(item.name)
                                .font(.largeTitle)
                                .bold()
                            Text("Тип")
                                .font(.headline)
                            Text(item.type.displayName)
                                .font(.title2)
                                .foregroundStyle(.blue)
                            Button("Удалить счёт", role: .destructive) {
                                if let item = selectedCategory {
                                    let service = CategoryService(context: context)
                                    service.dellCategory(item)
                                    selectedCategory = nil
                                }
                            }
                        }
                        .padding()
                    }
                    Text("Категории расходов")
                        .font(.title2)
                        .background(Color(.systemGroupedBackground))
                    List(expenseCategories) { category in
                            Button(action: {
                                selectedCategory = category
                            }) {
                                HStack {
                                    Text(category.name)
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                    .overlay {
                        if expenseCategories.isEmpty {
                            ContentUnavailableView("Нет категорий", systemImage: "bag.badge.minus")
                        }
                    }
                    .sheet(item: $selectedCategory) { item in
                        VStack(spacing: 16) {
                            Text("Категория")
                                .font(.headline)
                            Text(item.name)
                                .font(.largeTitle)
                                .bold()
                            Text("Тип")
                                .font(.headline)
                            Text(item.type.displayName)
                                .font(.title2)
                                .foregroundStyle(.blue)
                            Button("Удалить счёт", role: .destructive) {
                                if let item = selectedCategory {
                                    let service = CategoryService(context: context)
                                    service.dellCategory(item)
                                    selectedCategory = nil
                                }
                            }
                        }
                        .padding()
                    }
                    
                    Button("+ Добавить Категорию") {
                        showAddCategorySheet = true
                        categoryName = ""
                        type = CategoryType.expense
                    }
                }
                .background(Color(.systemGroupedBackground))
                
                Spacer()
                // кнопка выхода из профиля пользователя и сброс id пользователя из UserDefaults
                Button("Выйти") {
                    UserDefaults.standard.removeObject(forKey: UserDefaultKeys.currentUserId)
                    isLogged = false
                }
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

struct AddAccountSheet: View {
    @Binding var accountName: String
    @Binding var startBalance: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    var body: some View {
        VStack {
            TextField("Название счёта", text: $accountName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            TextField("Начальный баланс", text: $startBalance)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.decimalPad)
            Button("Добавить") {
                guard let balance = Decimal(string: startBalance.trimmingCharacters(in: .whitespaces)) else {
                    print("Введен не корректный баланс")
                    return
                }
                let service = AccountService(context: context)
                service.addAccount(accountName: accountName, startBalance: balance)
                dismiss()
            }
            Button("Отменить") {
                dismiss()
            }
        }
    }
}

struct AddCategorySheet: View {
    @Binding var categoryName: String
    @Binding var type: CategoryType
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    var body: some View {
        VStack {
            TextField("Название категории", text: $categoryName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            Picker("Тип", selection: $type) {
                Text("Доход").tag(CategoryType.income)
                Text("Расход").tag(CategoryType.expense)
            }
            Button("Добавить") {
                guard !categoryName.isEmpty else {
                    print("Не заполнена информация")
                    return
                }
                let service = CategoryService(context: context)
                service.addCategory(categoryName: categoryName, type: type)
                dismiss()
            }
            Button("Отмена") {
                dismiss()
            }
        }
    }
}
