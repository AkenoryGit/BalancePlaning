//
//  ViewModifiers.swift
//  BalancePlaning
//

import SwiftUI

// MARK: - cardStyle()

struct CardModifier: ViewModifier {
    var tint: Color? = nil
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
                    if let tint { tint.opacity(0.08) }
                }
            }
            .clipShape(shape)
            .overlay {
                if let tint {
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
