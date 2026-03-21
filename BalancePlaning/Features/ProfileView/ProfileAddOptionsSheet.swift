//
//  ProfileAddOptionsSheet.swift
//  BalancePlaning
//

import SwiftUI
import SwiftData

/// Модальное окно выбора что добавить, открывается кнопкой «+» на вкладке «Профиль»
struct ProfileAddOptionsSheet: View {
    @Query private var allGroups: [AccountGroup]

    @State private var showAddAccount  = false
    @State private var showAddCategory = false
    @State private var showAddCurrency = false

    @State private var categoryType: CategoryType = .expense

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Добавить")
                    .font(.title2.bold())

                optionButton(icon: "creditcard.fill", color: AppTheme.Colors.transfer, title: "Новый счёт") {
                    showAddAccount = true
                }

                optionButton(icon: "tag.fill", color: AppTheme.Colors.accent, title: "Новая категория") {
                    showAddCategory = true
                }

                optionButton(icon: "dollarsign.circle.fill", color: AppTheme.Colors.income, title: "Новая валюта") {
                    showAddCurrency = true
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom)
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAddAccount) {
            AddAccountSheet(groups: allGroups)
        }
        .sheet(isPresented: $showAddCategory) {
            AddCategorySheet(type: $categoryType)
        }
        .sheet(isPresented: $showAddCurrency) {
            AddCurrencySheet()
        }
    }

    private func optionButton(icon: String, color: Color, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                    .frame(width: 36, height: 36)
                    .background(color.opacity(0.12))
                    .clipShape(Circle())
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
