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

    var body: some View {
        VStack {
            Text(isIncome ? "Категории доходов" : "Категории расходов")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.horizontal)
            ForEach(filteredCategories) { category in
                Button(action: { selectedCategory = category }) {
                    HStack {
                        Spacer()
                        Text(category.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                .padding(.horizontal, 20)
            }
        }
        .overlay {
            if filteredCategories.isEmpty {
                ContentUnavailableView("Нет категорий", systemImage: "bag.badge.minus")
            }
        }
        .sheet(item: $selectedCategory) { item in
            VStack(spacing: 16) {
                Text("Категория")
                    .font(.headline)
                Text(item.name)
                    .font(.largeTitle)
                    .bold()
                Text("Тип")
                    .font(.headline)
                Text(item.type.displayName)
                    .font(.title2)
                    .foregroundStyle(.blue)
                Button("Удалить категорию", role: .destructive) {
                    let service = CategoryService(context: context)
                    service.deleteCategory(item)
                    selectedCategory = nil
                }
            }
            .padding()
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
