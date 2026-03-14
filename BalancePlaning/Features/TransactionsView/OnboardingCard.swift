//
//  OnboardingCard.swift
//  BalancePlaning
//

import SwiftUI

// MARK: - Онбординг (нет счетов)

struct OnboardingCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "hand.wave.fill")
                    .font(.title2)
                    .foregroundStyle(AppTheme.Colors.accent)
                Text("Добро пожаловать!")
                    .font(.headline)
            }

            Text("Чтобы начать, перейдите во вкладку **Профиль** и создайте свой первый счёт — например, «Наличные» или «Карта».")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                OnboardingStep(number: "1", text: "Создайте счёт в разделе «Профиль»")
                OnboardingStep(number: "2", text: "Добавьте первую операцию кнопкой «+»")
                OnboardingStep(number: "3", text: "Следите за балансом и аналитикой")
            }
        }
        .padding(16)
        .cardStyle(tint: AppTheme.Colors.accent)
    }
}

// MARK: - Шаг онбординга

private struct OnboardingStep: View {
    let number: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Text(number)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(AppTheme.Colors.accent)
                .clipShape(Circle())
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
