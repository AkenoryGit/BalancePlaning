//
//  AppTheme.swift
//  BalancePlaning
//

import SwiftUI

// MARK: - Цвета и константы дизайн-системы

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
        /// Фон страниц (адаптивный: светло-серый в светлой теме, тёмный в тёмной)
        static let pageBackground = Color(.systemGroupedBackground)
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

// MARK: - Палитра цветов для категорий

enum CategoryColors {
    struct Swatch: Identifiable {
        let hex: String
        var id: String { hex }
        var color: Color { Color(hex: hex) }
    }

    static let palette: [Swatch] = [
        .init(hex: "FF4B4B"), // Красный
        .init(hex: "FF8C42"), // Оранжевый
        .init(hex: "F9C74F"), // Жёлтый
        .init(hex: "57CC99"), // Зелёный
        .init(hex: "17C3B2"), // Бирюзовый
        .init(hex: "4CC9F0"), // Голубой
        .init(hex: "4361EE"), // Синий
        .init(hex: "9D4EDD"), // Фиолетовый
        .init(hex: "F72585"), // Розовый
        .init(hex: "C77DFF"), // Лиловый
        .init(hex: "8B5E3C"), // Коричневый
        .init(hex: "7B8FA1"), // Серый
    ]

    /// Возвращает Color по hex-строке, nil если строка пуста
    static func resolve(_ hex: String) -> Color? {
        hex.isEmpty ? nil : Color(hex: hex)
    }
}

// MARK: - TransactionType: цвет, иконка, префикс суммы

extension TransactionType {
    var color: Color {
        switch self {
        case .transaction: return AppTheme.Colors.transfer
        case .expense:     return AppTheme.Colors.expense
        case .income:      return AppTheme.Colors.income
        case .correction:  return Color.secondary
        }
    }

    var icon: String {
        switch self {
        case .transaction: return "arrow.left.arrow.right.circle.fill"
        case .expense:     return "minus.circle.fill"
        case .income:      return "plus.circle.fill"
        case .correction:  return "arrow.triangle.2.circlepath.circle.fill"
        }
    }

    /// "+" / "−" / "" перед суммой
    var amountPrefix: String {
        switch self {
        case .transaction: return ""
        case .expense:     return "−"
        case .income:      return "+"
        case .correction:  return ""
        }
    }
}

// MARK: - TransactionPriority: цвета

extension TransactionPriority {
    /// Цвет левой полоски на карточке. Для .normal — прозрачный (не отображается)
    var stripeColor: Color {
        switch self {
        case .mandatory: return AppTheme.Colors.expense
        case .important: return Color(hex: "F59E0B")
        case .normal:    return Color.clear
        }
    }

    /// Цвет активного состояния кнопки выбора важности
    var activeColor: Color {
        switch self {
        case .mandatory: return AppTheme.Colors.expense
        case .important: return Color(hex: "F59E0B")
        case .normal:    return AppTheme.Colors.accent
        }
    }
}
