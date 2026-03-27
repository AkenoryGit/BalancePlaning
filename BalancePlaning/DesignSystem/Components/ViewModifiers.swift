//
//  ViewModifiers.swift
//  BalancePlaning
//

import SwiftUI

// MARK: - cardStyle()

struct CardModifier: ViewModifier {
    var tint: Color? = nil
    /// Двухцветный горизонтальный градиент (leading, trailing) — заменяет flat tint
    var gradientColors: (Color, Color)? = nil
    var trailingRadius: CGFloat = AppTheme.cardRadius

    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: AppTheme.cardRadius,
            bottomLeadingRadius: AppTheme.cardRadius,
            bottomTrailingRadius: trailingRadius,
            topTrailingRadius: trailingRadius
        )
    }

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    Color(.secondarySystemGroupedBackground)
                    if let (leading, trailing) = gradientColors {
                        LinearGradient(
                            colors: [leading.opacity(0.10), trailing.opacity(0.06)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    } else if let tint {
                        tint.opacity(0.08)
                    }
                }
            }
            .clipShape(shape)
            .overlay {
                // Бордер — только для flat-tint карточек (градиентные выглядят чище без него)
                if gradientColors == nil, let tint {
                    shape
                        .inset(by: 0.75)
                        .stroke(tint.opacity(0.55), lineWidth: 1.5)
                }
            }
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
    }
}

extension View {
    func cardStyle(tint: Color? = nil, trailingRadius: CGFloat = AppTheme.cardRadius) -> some View {
        modifier(CardModifier(tint: tint, trailingRadius: trailingRadius))
    }

    /// Карточка с горизонтальным градиентом слева направо
    func cardStyleGradient(leading: Color, trailing: Color, trailingRadius: CGFloat = AppTheme.cardRadius) -> some View {
        modifier(CardModifier(gradientColors: (leading, trailing), trailingRadius: trailingRadius))
    }
}

// MARK: - dismissKeyboardOnDrag()

extension View {
    func dismissKeyboardOnDrag() -> some View {
        self
            .scrollDismissesKeyboard(.immediately)
            .simultaneousGesture(
                DragGesture(minimumDistance: 12).onChanged { _ in
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                }
            )
    }
}
