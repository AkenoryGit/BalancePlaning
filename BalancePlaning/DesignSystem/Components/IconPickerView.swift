//
//  IconPickerView.swift
//  BalancePlaning
//

import SwiftUI

/// Горизонтальная строка для выбора иконки из набора SF Symbols.
/// selectedIcon == "" означает «иконка по умолчанию».
struct IconPickerView: View {
    @Binding var selectedIcon: String
    let icons: [String]
    let accentColor: Color

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {

                // «Без иконки» — возвращает к иконке по умолчанию
                Button { selectedIcon = "" } label: {
                    let selected = selectedIcon.isEmpty
                    ZStack {
                        Circle()
                            .stroke(Color.secondary.opacity(0.4), lineWidth: 1.5)
                            .frame(width: 36, height: 36)
                        Image(systemName: "xmark")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                    .overlay(selected ? Circle().stroke(Color.primary, lineWidth: 2.5) : nil)
                    .scaleEffect(selected ? 1.15 : 1.0)
                    .animation(.spring(response: 0.25), value: selected)
                }

                ForEach(icons, id: \.self) { icon in
                    Button { selectedIcon = icon } label: {
                        let selected = selectedIcon == icon
                        ZStack {
                            Circle()
                                .fill(selected ? accentColor : accentColor.opacity(0.1))
                                .frame(width: 36, height: 36)
                            Image(systemName: icon)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(selected ? .white : accentColor)
                        }
                        .overlay(selected ? Circle().stroke(Color.primary.opacity(0.25), lineWidth: 2.5) : nil)
                        .scaleEffect(selected ? 1.15 : 1.0)
                        .animation(.spring(response: 0.25), value: selected)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
}
