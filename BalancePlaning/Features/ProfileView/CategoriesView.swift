//
//  CategoriesView.swift
//  BalancePlaning
//
//  Created by Дмитрий Дудник on 26.02.2026.
//

import SwiftUI
import SwiftData

struct CategoriesView: View {
    @Environment(\.modelContext) private var context

    @State private var selectedCategory: Category?

    @Query(sort: \Category.name) private var allCategories: [Category]

    var isIncome: Bool

    private var filteredCategories: [Category] {
        guard let userId = currentUserId() else { return [] }
        let type: CategoryType = isIncome ? .income : .expense
        return allCategories.filter { $0.userId == userId && $0.type == type }
    }

    private var accentColor: Color {
        isIncome ? AppTheme.Colors.income : AppTheme.Colors.expense
    }

    private var categoryIcon: String {
        isIncome ? "arrow.down.circle.fill" : "arrow.up.circle.fill"
    }

    var body: some View {
        VStack(spacing: 6) {
            ForEach(filteredCategories) { category in
                Button(action: { selectedCategory = category }) {
                    HStack(spacing: 14) {
                        Image(systemName: categoryIcon)
                            .font(.title3)
                            .foregroundStyle(accentColor)
                            .frame(width: 40, height: 40)
                            .background(accentColor.opacity(0.1))
                            .clipShape(Circle())

                        Text(category.name)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(14)
                    .cardStyle()
                    .padding(.horizontal, 20)
                }
            }
        }
        .overlay {
            if filteredCategories.isEmpty {
                ContentUnavailableView("Нет категорий", systemImage: "tag")
                    .padding(.top, 20)
            }
        }
        .sheet(item: $selectedCategory) { item in
            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.secondary.opacity(0.4))
                    .frame(width: 40, height: 4)
                    .padding(.top, 12)
                    .padding(.bottom, 20)

                Image(systemName: categoryIcon)
                    .font(.system(size: 44))
                    .foregroundStyle(accentColor)
                    .padding(.bottom, 8)

                Text(item.name)
                    .font(.title2.bold())

                Text(item.type.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                    .padding(.bottom, 32)

                Button(role: .destructive) {
                    CategoryService(context: context).deleteCategory(item)
                    selectedCategory = nil
                } label: {
                    Label("Удалить категорию", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .presentationDetents([.medium])
        }
    }
}

struct AddCategorySheet: View {
    @Binding var categoryName: String
    @Binding var type: CategoryType
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Новая категория")
                    .font(.title2.bold())
                TextField("Название категории", text: $categoryName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                Button("Добавить") {
                    guard !categoryName.isEmpty else {
                        print("Не заполнена информация")
                        return
                    }
                    let service = CategoryService(context: context)
                    service.addCategory(categoryName: categoryName, type: type)
                    dismiss()
                }
                Button("Отмена") {
                    dismiss()
                }
            }
            .padding()
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}
