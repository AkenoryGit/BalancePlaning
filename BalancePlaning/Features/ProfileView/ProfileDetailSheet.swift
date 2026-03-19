//
//  ProfileDetailSheet.swift
//  BalancePlaning
//

import SwiftUI
import SwiftData

struct ProfileDetailSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let user: User

    @State private var displayName: String
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""

    @State private var didAttemptSave = false
    @State private var passwordError = ""
    @State private var showSuccess = false

    init(user: User) {
        self.user = user
        self._displayName = State(initialValue: user.displayName)
    }

    private var userService: UserService { UserService(context: context) }

    private var isChangingPassword: Bool {
        !currentPassword.isEmpty || !newPassword.isEmpty || !confirmPassword.isEmpty
    }

    private var newPasswordsMatch: Bool { newPassword == confirmPassword }

    private var avatarLetter: String {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return String((name.isEmpty ? user.login : name).prefix(1)).uppercased()
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHandle().padding(.bottom, 20)

            // Аватар + логин
            VStack(spacing: 6) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.Colors.accent, AppTheme.Colors.accentSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 72)
                    .overlay {
                        Text(avatarLetter)
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(.white)
                    }

                Text(user.login)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 24)

            ScrollView {
                VStack(spacing: 20) {

                    // Имя в приложении
                    profileSection(title: "Имя в приложении") {
                        HStack(spacing: 12) {
                            Image(systemName: "person.fill")
                                .foregroundStyle(AppTheme.Colors.accent).frame(width: 20)
                            TextField("Как вас называть?", text: $displayName)
                                .autocorrectionDisabled()
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Логин (read-only)
                    profileSection(title: "Логин") {
                        HStack(spacing: 12) {
                            Image(systemName: "envelope")
                                .foregroundStyle(.secondary).frame(width: 20)
                            Text(user.login).foregroundStyle(.secondary)
                            Spacer()
                            Image(systemName: "lock.fill")
                                .font(.caption).foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Смена пароля
                    profileSection(title: "Смена пароля") {
                        VStack(spacing: 10) {
                            AuthSecureField(icon: "lock",
                                            placeholder: "Текущий пароль",
                                            text: $currentPassword)
                            AuthSecureField(icon: "lock.open",
                                            placeholder: "Новый пароль",
                                            text: $newPassword)
                            AuthSecureField(icon: "checkmark.shield",
                                            placeholder: "Повторите новый пароль",
                                            text: $confirmPassword)

                            if didAttemptSave && isChangingPassword && !passwordError.isEmpty {
                                Label(LocalizedStringKey(passwordError), systemImage: "exclamationmark.circle.fill")
                                    .font(.caption).foregroundStyle(.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            } else if didAttemptSave && isChangingPassword && !newPasswordsMatch {
                                Label("Пароли не совпадают", systemImage: "exclamationmark.circle.fill")
                                    .font(.caption).foregroundStyle(.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .onChange(of: currentPassword) { _, _ in resetErrors() }
                        .onChange(of: newPassword)     { _, _ in resetErrors() }
                        .onChange(of: confirmPassword) { _, _ in resetErrors() }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .dismissKeyboardOnDrag()

            VStack(spacing: 12) {
                PrimaryButton(title: LocalizedStringKey(showSuccess ? "Сохранено ✓" : "Сохранить")) {
                    handleSave()
                }
                Button("Отмена", role: .cancel) { dismiss() }.foregroundStyle(.secondary)
            }
            .padding(.horizontal).padding(.bottom, 32)
        }
        .presentationDetents([.large])
        .animation(.easeInOut(duration: 0.2), value: didAttemptSave)
        .animation(.easeInOut(duration: 0.2), value: passwordError)
    }

    private func profileSection<Content: View>(title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            content()
        }
    }

    private func resetErrors() {
        if didAttemptSave { withAnimation { didAttemptSave = false; passwordError = "" } }
    }

    private func handleSave() {
        withAnimation { didAttemptSave = true; passwordError = "" }

        if isChangingPassword {
            guard !currentPassword.isEmpty,
                  !newPassword.isEmpty,
                  newPasswordsMatch else { return }

            if let error = userService.changePassword(for: user, current: currentPassword, new: newPassword) {
                withAnimation { passwordError = error }
                return
            }
            currentPassword = ""; newPassword = ""; confirmPassword = ""
        }

        userService.updateDisplayName(user, displayName: displayName)
        didAttemptSave = false
        withAnimation { showSuccess = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { dismiss() }
    }
}
