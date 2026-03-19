//
//  SharedComponents.swift
//  BalancePlaning
//

import SwiftUI

// MARK: - SheetHandle (индикатор перетаскивания шита)

struct SheetHandle: View {
    var body: some View {
        Capsule()
            .fill(Color.secondary.opacity(0.4))
            .frame(width: 40, height: 4)
            .padding(.top, 12)
    }
}

// MARK: - PrimaryButton (градиентная кнопка)

struct PrimaryButton: View {
    let title: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [AppTheme.Colors.accent, AppTheme.Colors.accentSecondary],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonRadius))
        }
    }
}
