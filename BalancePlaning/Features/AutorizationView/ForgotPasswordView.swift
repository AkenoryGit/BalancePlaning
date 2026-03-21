//
//  ForgotPasswordView.swift
//  BalancePlaning
//

import SwiftUI

struct ForgotPasswordView: View {
    let users: [User]
    @Environment(\.dismiss) private var dismiss

    // Шаг 1: email
    @State private var email = ""
    @State private var emailError = ""

    // Шаг 2: ответ на вопрос
    @State private var answer = ""
    @State private var answerError = ""

    // Шаг 3: новый пароль
    @State private var newPassword = ""
    @State private var newPasswordConfirm = ""
    @State private var passwordError = ""

    @State private var step: Int = 1
    @State private var foundUser: User?
    @State private var showSuccess = false

    var body: some View {
        VStack(spacing: 0) {
            // Заголовок
            VStack(spacing: 4) {
                Image(systemName: "lock.rotation")
                    .font(.system(size: 48))
                    .foregroundStyle(AppTheme.Colors.accent)
                    .padding(.bottom, 8)
                Text("Восстановление пароля")
                    .font(.title3.bold())
                Text(stepSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 32)
            .padding(.horizontal, 24)
            .padding(.bottom, 28)

            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    switch step {
                    case 1: emailStep
                    case 2: questionStep
                    case 3: newPasswordStep
                    default: EmptyView()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
            }
        }
        .alert("Пароль изменён", isPresented: $showSuccess) {
            Button("Войти") { dismiss() }
        } message: {
            Text("Новый пароль успешно сохранён.")
        }
    }

    // MARK: - Шаг 1: email

    private var emailStep: some View {
        VStack(spacing: 16) {
            AuthTextField(icon: "envelope", placeholder: "Email", text: $email, keyboardType: .emailAddress)

            AuthErrorLabel(message: emailError)

            AuthPrimaryButton(title: "Продолжить") { submitEmail() }
        }
    }

    // MARK: - Шаг 2: секретный вопрос

    private var questionStep: some View {
        VStack(spacing: 16) {
            if let q = foundUser?.securityQuestion, !q.isEmpty {
                Text(q)
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            AuthTextField(icon: "key", placeholder: "Ваш ответ", text: $answer)

            AuthErrorLabel(message: answerError)

            AuthPrimaryButton(title: "Продолжить") { submitAnswer() }

            Button("Назад") { step = 1; answerError = "" }
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Шаг 3: новый пароль

    private var newPasswordStep: some View {
        VStack(spacing: 16) {
            AuthSecureField(icon: "lock", placeholder: "Новый пароль", text: $newPassword)
            AuthSecureField(icon: "lock.shield", placeholder: "Подтвердите пароль", text: $newPasswordConfirm)

            AuthErrorLabel(message: passwordError)

            AuthPrimaryButton(title: "Сохранить пароль") { submitNewPassword() }

            Button("Назад") { step = 2; passwordError = "" }
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private var stepSubtitle: String {
        switch step {
        case 1: return "Введите email вашего аккаунта"
        case 2: return "Ответьте на секретный вопрос"
        case 3: return "Придумайте новый пароль"
        default: return ""
        }
    }

    private func submitEmail() {
        withAnimation { emailError = "" }
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { withAnimation { emailError = "Введите email" }; return }
        guard let user = users.first(where: { $0.login == trimmed }) else {
            withAnimation { emailError = "Аккаунт не найден" }; return
        }
        guard !user.securityQuestion.isEmpty else {
            withAnimation { emailError = "У этого аккаунта нет секретного вопроса. Пересоздайте аккаунт." }; return
        }
        foundUser = user
        step = 2
    }

    private func submitAnswer() {
        withAnimation { answerError = "" }
        guard let user = foundUser else { return }
        let trimmed = answer.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { withAnimation { answerError = "Введите ответ" }; return }
        guard let stored = KeychainManager.getSecurityAnswer(for: user.id) else {
            withAnimation { answerError = "Не удалось проверить ответ" }; return
        }
        guard trimmed.lowercased() == stored else {
            withAnimation { answerError = "Неверный ответ" }; return
        }
        step = 3
    }

    private func submitNewPassword() {
        withAnimation { passwordError = "" }
        guard newPassword.count >= 8 else {
            withAnimation { passwordError = "Пароль минимум 8 символов" }; return
        }
        guard newPassword == newPasswordConfirm else {
            withAnimation { passwordError = "Пароли не совпадают" }; return
        }
        guard let user = foundUser else { return }
        do {
            try KeychainManager.updatePassword(newPassword, for: user.id)
            showSuccess = true
        } catch {
            withAnimation { passwordError = "Ошибка сохранения: \(error.localizedDescription)" }
        }
    }
}
