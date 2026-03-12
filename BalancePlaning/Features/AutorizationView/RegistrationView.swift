//
//  RegistrationView.swift
//  BalancePlaning
//
//  Created by Дмитрий Дудник on 05.02.2026.
//

import SwiftUI
import SwiftData

struct RegistrationView: View {
    @Environment(\.modelContext) private var modelContext

    @Binding var isRegistration: Bool
    @Binding var isLogin: Bool

    @Query(filter: #Predicate<User> { _ in true }) private var allUsers: [User]

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var passwordConfirm: String = ""
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

            // Герой-секция
            AuthHeroView()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 100)

            // Белая панель с формой
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Создать аккаунт")
                        .font(.title2.bold())
                    Text("Начните вести учёт финансов")
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
                    AuthSecureField(
                        icon: "lock.shield",
                        placeholder: "Подтвердите пароль",
                        text: $passwordConfirm
                    )
                }

                AuthErrorLabel(message: errorMessage)

                AuthPrimaryButton(title: "Создать аккаунт", action: attemptRegister)

                HStack(spacing: 4) {
                    Text("Уже есть аккаунт?")
                        .foregroundStyle(.secondary)
                    Button("Войти") {
                        isRegistration = false
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

    private func attemptRegister() {
        withAnimation { errorMessage = "" }
        guard !email.isEmpty else { withAnimation { errorMessage = "Введите email" }; return }
        guard email.isValidEmail else { withAnimation { errorMessage = "Неверный формат email" }; return }
        guard !password.isEmpty else { withAnimation { errorMessage = "Введите пароль" }; return }
        guard password.count >= 8 else { withAnimation { errorMessage = "Пароль минимум 8 символов" }; return }
        guard password == passwordConfirm else { withAnimation { errorMessage = "Пароли не совпадают" }; return }
        guard !allUsers.contains(where: { $0.login == email }) else {
            withAnimation { errorMessage = "Такой аккаунт уже существует" }; return
        }
        do {
            let newUser = User(login: email)
            modelContext.insert(newUser)
            try modelContext.save()
            try KeychainManager.save(password: password, id: newUser.id)
            UserDefaults.standard.set(newUser.id.uuidString, forKey: UserDefaultKeys.currentUserId)
            isLogin = true
        } catch KeychainError.duplicateItem {
            withAnimation { errorMessage = "Такой аккаунт уже существует" }
        } catch {
            withAnimation { errorMessage = "Ошибка: \(error.localizedDescription)" }
        }
    }
}
