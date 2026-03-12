//
//  AutorizationView.swift
//  BalancePlaning
//
//  Created by Дмитрий Дудник on 05.02.2026.
//

import SwiftUI
import SwiftData

struct AutorizationView: View {
    @Binding var isRegistration: Bool
    @Binding var isLogged: Bool

    @Query(sort: \User.login) private var users: [User]

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String = ""

    var body: some View {
        ZStack(alignment: .bottom) {
            // Градиентный фон на весь экран
            LinearGradient(
                colors: [AppTheme.Colors.accent, AppTheme.Colors.accentSecondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Герой-секция: иконка + название
            AuthHeroView()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 100)

            // Белая панель с формой
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Добро пожаловать")
                        .font(.title2.bold())
                    Text("Войдите в свой аккаунт")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 10) {
                    AuthTextField(
                        icon: "envelope",
                        placeholder: "Email",
                        text: $email,
                        keyboardType: .emailAddress
                    )
                    AuthSecureField(
                        icon: "lock",
                        placeholder: "Пароль",
                        text: $password
                    )
                }

                AuthErrorLabel(message: errorMessage)

                AuthPrimaryButton(title: "Войти", action: attemptLogin)

                HStack(spacing: 4) {
                    Text("Нет аккаунта?")
                        .foregroundStyle(.secondary)
                    Button("Зарегистрироваться") {
                        isRegistration = true
                    }
                    .foregroundStyle(AppTheme.Colors.accent)
                    .fontWeight(.medium)
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .padding(.bottom, 48)
            .background(
                RoundedRectangle(cornerRadius: 32)
                    .fill(Color(.systemBackground))
                    .ignoresSafeArea(edges: .bottom)
            )
            .animation(.easeInOut(duration: 0.2), value: errorMessage)
        }
    }

    private func attemptLogin() {
        withAnimation { errorMessage = "" }
        guard !email.isEmpty else { withAnimation { errorMessage = "Введите email" }; return }
        guard email.isValidEmail else { withAnimation { errorMessage = "Неверный формат email" }; return }
        guard password.count >= 8 else { withAnimation { errorMessage = "Пароль менее 8 символов" }; return }
        guard let foundUser = users.first(where: { $0.login == email }) else {
            withAnimation { errorMessage = "Пользователь не найден" }; return
        }
        guard let data = try? KeychainManager.getPassword(for: foundUser.id),
              let stored = String(data: data, encoding: .utf8) else {
            withAnimation { errorMessage = "Ошибка чтения пароля" }; return
        }
        guard stored == password else {
            withAnimation { errorMessage = "Неверный пароль" }; return
        }
        UserDefaults.standard.set(foundUser.id.uuidString, forKey: UserDefaultKeys.currentUserId)
        isLogged = true
    }
}

extension String {
    var isValidEmail: Bool {
        NSPredicate(format: "SELF MATCHES %@", "[A-Z0-9a-z._%+-]+@[A-Za-z0-9-]+\\.[A-Za-z]{2,}")
            .evaluate(with: self)
    }
}
