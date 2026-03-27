//
//  BankIcon.swift
//  BalancePlaning
//

import SwiftUI

// MARK: - Данные банка

struct BankInfo: Identifiable {
    let id: String
    let name: String
    let abbreviation: String
    let hex: String
    var darkText: Bool = false
}

// MARK: - Список банков

enum BankIcons {
    static let all: [BankInfo] = [
        BankInfo(id: "sber",    name: "Сбербанк",       abbreviation: "СБ",  hex: "21A038"),
        BankInfo(id: "vtb",     name: "ВТБ",            abbreviation: "ВТБ", hex: "009FDF"),
        BankInfo(id: "alfa",    name: "Альфа-Банк",     abbreviation: "АЛФ", hex: "EF3124"),
        BankInfo(id: "tbank",   name: "Т-Банк",         abbreviation: "ТБ",  hex: "FFDD2D", darkText: true),
        BankInfo(id: "gazprom", name: "Газпромбанк",    abbreviation: "ГПБ", hex: "0067AC"),
        BankInfo(id: "rshb",    name: "Россельхозбанк", abbreviation: "РХБ", hex: "009E49"),
        BankInfo(id: "sovkom",  name: "Совкомбанк",     abbreviation: "СКМ", hex: "F26522"),
        BankInfo(id: "otkr",    name: "Банк Открытие",  abbreviation: "ОТК", hex: "0098C2"),
        BankInfo(id: "mkb",     name: "МКБ",            abbreviation: "МКБ", hex: "D42026"),
        BankInfo(id: "pochta",  name: "Почта Банк",     abbreviation: "ПБ",  hex: "006DB7"),
        BankInfo(id: "ros",     name: "Росбанк",        abbreviation: "РОС", hex: "1E3A7B"),
        BankInfo(id: "raif",    name: "Райффайзен",     abbreviation: "РФЗ", hex: "EAB40A", darkText: true),
    ]

    static func info(for id: String) -> BankInfo? {
        all.first { $0.id == id }
    }
}

// MARK: - Бэйдж иконки банка

struct BankIconBadge: View {
    let iconId: String
    var size: CGFloat = 44

    var body: some View {
        if let bank = BankIcons.info(for: iconId) {
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.25)
                    .fill(Color(hex: bank.hex))
                    .frame(width: size, height: size)
                Text(bank.abbreviation)
                    .font(.system(size: size * 0.27, weight: .bold, design: .rounded))
                    .foregroundStyle(bank.darkText ? Color.black.opacity(0.75) : .white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .padding(.horizontal, 2)
            }
        } else {
            Image(systemName: "building.columns.fill")
                .font(.system(size: size * 0.42))
                .foregroundStyle(Color(hex: "E74C3C"))
                .frame(width: size, height: size)
                .background(Color(hex: "E74C3C").opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: size * 0.25))
        }
    }
}

// MARK: - Пикер банка

struct BankIconPickerSheet: View {
    @Binding var selectedId: String
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 76), spacing: 16)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    LazyVGrid(columns: columns, spacing: 20) {
                        // По умолчанию
                        bankCell(iconId: "", name: "По умолч.")

                        ForEach(BankIcons.all) { bank in
                            bankCell(iconId: bank.id, name: bank.name)
                        }
                    }
                }
                .padding()
            }
            .background(AppTheme.Colors.pageBackground)
            .navigationTitle("Иконка банка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                }
            }
        }
    }

    private func bankCell(iconId: String, name: String) -> some View {
        let isSelected = selectedId == iconId
        return Button {
            selectedId = iconId
            dismiss()
        } label: {
            VStack(spacing: 6) {
                BankIconBadge(iconId: iconId, size: 56)
                    .overlay(
                        isSelected
                            ? RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.primary, lineWidth: 2.5)
                            : nil
                    )
                    .scaleEffect(isSelected ? 1.08 : 1.0)
                    .animation(.spring(response: 0.25), value: isSelected)
                Text(name)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: 70)
            }
        }
        .buttonStyle(.plain)
    }
}
