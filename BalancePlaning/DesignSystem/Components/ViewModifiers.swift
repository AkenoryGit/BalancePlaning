//
//  ViewModifiers.swift
//  BalancePlaning
//

import SwiftUI

// MARK: - cardStyle()

struct CardModifier: ViewModifier {
    var tint: Color? = nil

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    Color(.secondarySystemGroupedBackground)
                    if let tint { tint.opacity(0.08) }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
            .overlay {
                if let tint {
                    RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                        .inset(by: 0.75)
                        .stroke(tint.opacity(0.55), lineWidth: 1.5)
                }
            }
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
    }
}

extension View {
    func cardStyle(tint: Color? = nil) -> some View {
        modifier(CardModifier(tint: tint))
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
