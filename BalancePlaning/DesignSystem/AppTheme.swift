//
//  AppTheme.swift
//  BalancePlaning
//

import SwiftUI
import SwiftData

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

// MARK: - SheetHandle (индикатор перетаскивания шита)

struct SheetHandle: View {
    var body: some View {
        Capsule()
            .fill(Color.secondary.opacity(0.4))
            .frame(width: 40, height: 4)
            .padding(.top, 12)
    }
}

// MARK: - PrimaryButton (градиентная кнопка без стрелки)

struct PrimaryButton: View {
    let title: String
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

// MARK: - dismissKeyboardOnDrag()

extension View {
    /// Скрывает клавиатуру при любом скролле или тапе вне поля ввода.
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
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
    }
}

extension View {
    func cardStyle(tint: Color? = nil) -> some View {
        modifier(CardModifier(tint: tint))
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

// MARK: - Плашка доходов/расходов с разбивкой по валютам

struct MultiCurrencyPill: View {
    let label: String
    let entries: [(code: String, amount: Decimal)]
    let color: Color
    let customCurrencies: [Currency]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            if entries.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("0")
                        .font(.headline.bold())
                        .foregroundStyle(color)
                    Text("₽")
                        .font(.subheadline.bold())
                        .foregroundStyle(color.opacity(0.8))
                }
            } else {
                ForEach(entries, id: \.code) { entry in
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(entry.amount, format: .number.precision(.fractionLength(0...2)))
                            .font(.headline.bold())
                            .foregroundStyle(color)
                        Text(CurrencyInfo.symbol(for: entry.code, custom: customCurrencies))
                            .font(.subheadline.bold())
                            .foregroundStyle(color.opacity(0.8))
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}
