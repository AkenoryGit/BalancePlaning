//
//  AppTheme.swift
//  BalancePlaning
//

import SwiftUI

// MARK: - Дизайн-система

enum AppTheme {
    enum Colors {
        /// Изумрудный — доходы
        static let income   = Color(hex: "00C897")
        /// Коралловый — расходы
        static let expense  = Color(hex: "FF6B6B")
        /// Лавандовый — переводы
        static let transfer = Color(hex: "7B8FFF")
        /// Индиго — основной акцент
        static let accent   = Color(hex: "4F46E5")
        /// Фиолетовый — второй акцент для градиента
        static let accentSecondary = Color(hex: "7C3AED")
        /// Фон страниц
        static let pageBackground = Color(hex: "F0F2F8")
    }

    static let cardRadius:   CGFloat = 16
    static let buttonRadius: CGFloat = 12
}

// MARK: - Color(hex:)

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 180, 180, 180)
        }
        self.init(.sRGB,
                  red:     Double(r) / 255,
                  green:   Double(g) / 255,
                  blue:    Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

// MARK: - TransactionType: цвет, иконка, префикс суммы

extension TransactionType {
    var color: Color {
        switch self {
        case .transaction: return AppTheme.Colors.transfer
        case .expense:     return AppTheme.Colors.expense
        case .income:      return AppTheme.Colors.income
        }
    }

    var icon: String {
        switch self {
        case .transaction: return "arrow.left.arrow.right.circle.fill"
        case .expense:     return "minus.circle.fill"
        case .income:      return "plus.circle.fill"
        }
    }

    /// "+" / "−" / "" перед суммой
    var amountPrefix: String {
        switch self {
        case .transaction: return ""
        case .expense:     return "−"
        case .income:      return "+"
        }
    }
}

// MARK: - cardStyle()

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardModifier())
    }
}

// MARK: - Общий компонент: плашка «Доходы / Расходы»

struct SummaryPill: View {
    let label: String
    let amount: Decimal
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(amount, format: .number.precision(.fractionLength(0...2)))
                    .font(.headline.bold())
                    .foregroundStyle(color)
                Text("₽")
                    .font(.subheadline.bold())
                    .foregroundStyle(color.opacity(0.8))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}
