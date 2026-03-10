//
//  RegistrationView.swift
//  BalancePlaning
//
//  Created by Дмитрий Дудник on 05.02.2026.
//

import SwiftUI
import SwiftData
import Security

struct RegistrationView: View {
    // подключаемся к базе SwiftData через context
    @Environment(\.modelContext) var modelContext
    
    @Binding var isRegistration: Bool
    @Binding var isLogin: Bool
    
    @State private var login: String = ""
    @State private var password: String = ""
    @State private var passwordConfirmation: String = ""
    @State private var status: String = ""
    
    // вытаскиваем из базы всех зарегистрированных поользователей
    @Query(filter: #Predicate<User> { _ in true }) private var allUsers: [User]
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 20) {
                Header(title: "Регистрация")
                    .frame(width: geometry.size.width, height: 250)
                VStack(spacing: 0) {
                    TextField("Логин", text: $login)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .frame(width: geometry.size.width - 40, height: 50)
                    CustomSecureField(password: $password, title: "Пароль")
                    CustomSecureField(password: $passwordConfirmation, title: "Пароль")
                }
                Button("Зарегистрироваться") {
                    if password.isEmpty {
                        status = "Пароль пустой"
                    } else if password != passwordConfirmation {
                        status = "Пароли не совпадают"
                    } else if password.count < 8 {
                        status = "Пароль должен быть не менее 8 символов"
                    } else if login.isEmpty  {
                        status = "Логин пустой"
                    } else if allUsers.contains(where: { $0.login == $login.wrappedValue }) {
                        status = "Пользователь с таким аккаунтом уже существует"
                    } else if !$login.wrappedValue.isValidEmail {
                            status = "Неверный формат email"
                    } else {
                        do {
                            try register(login: login, password: password)
                                status = "Вы успешно зарегистрировались!"
                                isLogin = true
                            } catch KeychainError.duplicateItem {
                                status = "Пользователь с таким аккаунтом уже существует"
                            } catch KeychainError.unowned(let statusError) {
                                status = "Ошибка \(statusError)"
                            } catch {
                                status = "Неизвестная ошибка"
                            }
                    }
                }
                Button("Уже зарегистрированы?") {
                    isRegistration = false
                }
                Text(status)
                    .foregroundStyle(Color.red)
            }
        }
    }
}

extension RegistrationView {
    // функция регистрации
    private func register(login: String, password: String) throws {
        // создаем нового пользователя в введенным логином
        let newUser = User(login: login)
        // вставляем нового пользователя в SwiftData
        modelContext.insert(newUser)
        // пробуем сохранить изменения в SwiftData
        try modelContext.save()
        
        // пробуем сохранить пароль в Keychain и привязать его к id нового пользователя
        try KeychainManager.save(password: password, id: newUser.id)
        // сохраняем id нового пользователя в UserDefaults
        UserDefaults.standard.set(newUser.id.uuidString, forKey: UserDefaultKeys.currentUserId)

    }
}

//#Preview {
//    RegistrationView(isRegistration: .constant(true), isLogin: .constant(false))
//}
