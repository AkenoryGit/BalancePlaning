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
    @Environment(\.modelContext) var modelContext
    
    @Binding var isRegistration: Bool
    
    @State private var login: String = ""
    @State private var password: String = ""
    @State private var passwordConfirmation: String = ""
    @State private var status: String = ""
    
    @Query(filter: #Predicate<User> { _ in true }) private var allUsers: [User]
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 20) {
                HeadSectionView(title: "Регистрация")
                    .frame(width: geometry.size.width, height: 250)
                VStack(spacing: 0) {
                    TextField("Логин", text: $login)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: geometry.size.width - 40, height: 50)
                    SecureField("Пароль", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: geometry.size.width - 40, height: 50)
                    SecureField("Повторите пароль", text: $passwordConfirmation)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: geometry.size.width - 40, height: 50)
                }
                Button("Зарегистрироваться") {
                    if password.isEmpty {
                        status = "Пароль пустой"
                    } else if password != passwordConfirmation {
                        status = "Пароли не совпадают"
                    } else if password.count < 8 {
                        status = "Пароль должен быть не менее 8 символов"
                    } else if allUsers.contains(where: { $0.login == $login.wrappedValue }) {
                        status = "Пользователь с таким аккаунтом уже существует"
                    } else {
                        do {
                            try register(login: login, password: password)
                                status = "Вы успешно зарегистрировались!"
                                isRegistration.toggle()
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
                Text("\(status)")
                    .foregroundStyle(Color.red)
            }
        }
    }
}

extension RegistrationView {
    private func register(login: String, password: String) throws {
        let newUser = User(login: login)
        modelContext.insert(newUser)
        try modelContext.save()
        
        try KeychainManager.save(password: password, id: newUser.id)
    }
}

#Preview {
    RegistrationView(isRegistration: .constant(true))
}
