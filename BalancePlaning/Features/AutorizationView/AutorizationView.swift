//
//  AutorizationView.swift
//  BalancePlaning
//
//  Created by Дмитрий Дудник on 05.02.2026.
//

import SwiftUI
import SwiftData

struct AutorizationView: View {
    // передаем в ContentView регистрация сейчас или авторизация
    @Binding var isRegistration: Bool
    // передаем в ContenView залогинился пользователь или нет
    @Binding var isLogged: Bool
    
    // выгружаем всех пользователей в переменную users
    @Query(sort: \User.login) var users:[User] = []
    
    // следим за изменениями в переменных статус, логин и пароль
    @State private var status: String = ""
    @State private var login: String = ""
    @State private var password: String = ""
    
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 20) {
                // устанавливаем хедер с титулом "Авторизация"
                Header(title: "Авторизация")
                    .frame(width: geometry.size.width, height: 250)
                // Поля ввода для логина и пароля
                VStack(spacing: 0) {
                    TextField("Логин", text: $login)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: geometry.size.width - 40, height: 50)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    SecureField("Пароль", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: geometry.size.width - 40, height: 50)
                }
                // кнопка "Войти" с проверкой корректности ввода формата почты и проверки не пустое ли поле с почтой
                Button {
                    if !login.isValidEmail && !login.isEmpty {
                        status = "Не верный формат почты"
                    } else if password.count < 8 {
                        status = "Пароль содержит менее 8 символов"
                    } else {
                        // если все корректно, то логинимся
                        login(email: login, password: password)
                    }
                } label: {
                    Text("Войти")
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .font(Font.system(size: 18, weight: .bold, design: .default))
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.green))
                        .foregroundColor(.white)
                }
                // кнопка перехода на окно регистрации
                Button {
                    isRegistration = true
                } label: {
                    Text("Зарегистрироваться")
                        .foregroundStyle(Color.blue)
                }
                // отображение статуса ввода логина и пароля
                Text(status)
                    .foregroundStyle(Color.red)
            }
        }
    }
}

extension AutorizationView {
    // функция авторизации пользователя
    private func login(email: String, password: String) {
        // проверяем есть ли в базе сохраненный пользователь с таким же логином
        guard let foundUser = users.first(where: { $0.login == email }) else {
            status = "Неверный логин"
            return
        }
        // записываем id найденного пользователя с таким же логином
        let userId = foundUser.id
        // создаем контейнер для хранения пароля пользователя
        var userPassword: Data?
        // пытаемся достать пароль пользователя с таким id
        do {
            userPassword = try KeychainManager.getPassword(for: userId)
        } catch {
            status = "Пароль пользователя не найден"
            return
        }
        // переводим найденный пароль в формат String
        guard let storedPassword = userPassword,
              let userStringPassword = String(data: storedPassword, encoding: .utf8) else {
            status = "Не удалось прочитать сохранённый пароль"
            return
        }
        
        // проверяем совпадает ли найденный пароль пользователя с введенным в SecureField
        if userStringPassword == password {
            // если совпали, то логинимся и сохраняем id пользователя в UserDefaults
            status = "Пользователь успешно авторизован"
            UserDefaults.standard.set(userId.uuidString, forKey: UserDefaultKeys.currentUserId)
            isLogged = true
        } else {
            status = "Неверный пароль"
        }
    }
}

extension String {
    // функция проверки корректности ввода логина в формате почты
    var isValidEmail: Bool {
            let emailPredicate = NSPredicate(format: "SELF MATCHES %@", "[A-Z0-9a-z._%+-]+@[A-Za-z0-9-]+\\.[A-Za-z]{2,}")
            return emailPredicate.evaluate(with: self)
        }
}
