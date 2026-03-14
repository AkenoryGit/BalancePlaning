//
//  CategoriesView.swift
//  BalancePlaning
//
//  Created by Дмитрий Дудник on 26.02.2026.
//

import SwiftUI
import SwiftData

// MARK: - Главный список категорий (с деревом)

struct CategoriesView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \Category.name) private var allCategories: [Category]
    @Query                       private var allTransactions: [Transaction]

    var isIncome: Bool

    // Категория, выбранная для просмотра / удаления
    @State private var selectedCategory: Category?
    // Показывать ли Bottom Sheet добавления подкатегории
    @State private var addSubcategoryParent: Category?
    // Раскрытые корневые категории
    @State private var expandedIds: Set<UUID> = []

    private var service: CategoryService { CategoryService(context: context) }

    private var accentColor: Color {
        isIncome ? AppTheme.Colors.income : AppTheme.Colors.expense
    }
    private var categoryIcon: String {
        isIncome ? "arrow.down.circle.fill" : "arrow.up.circle.fill"
    }

    private var userId: UUID? { currentUserId() }

    private var rootCategories: [Category] {
        guard let uid = userId else { return [] }
        let type: CategoryType = isIncome ? .income : .expense
        return allCategories
            .filter { $0.userId == uid && $0.type == type && $0.isRoot && !$0.isDefault }
            .sorted { $0.name < $1.name }
    }

    private func childCategories(of parent: Category) -> [Category] {
        allCategories
            .filter { $0.parentId == parent.id }
            .sorted { $0.name < $1.name }
    }

    private func childCount(of cat: Category) -> Int {
        childCategories(of: cat).count
    }

    var body: some View {
        VStack(spacing: 6) {
            if rootCategories.isEmpty {
                ContentUnavailableView("Нет категорий", systemImage: "tag")
                    .padding(.top, 20)
            } else {
                ForEach(rootCategories) { root in
                    let children = childCategories(of: root)
                    let isExpanded = expandedIds.contains(root.id)
                    let rootTint = CategoryColors.resolve(root.color)

                    VStack(spacing: 4) {
                        // Строка корневой категории
                        CategoryRow(
                            category: root,
                            accentColor: accentColor,
                            icon: categoryIcon,
                            childCount: children.count,
                            isExpanded: isExpanded,
                            isChild: false,
                            categoryColor: rootTint
                        ) {
                            if children.isEmpty {
                                selectedCategory = root
                            } else {
                                withAnimation(.spring(response: 0.3)) {
                                    if isExpanded { expandedIds.remove(root.id) }
                                    else          { expandedIds.insert(root.id) }
                                }
                            }
                        } onLongPress: {
                            selectedCategory = root
                        }
                        .padding(.horizontal, 20)

                        // Дочерние категории
                        if isExpanded {
                            ForEach(children) { child in
                                CategoryRow(
                                    category: child,
                                    accentColor: accentColor,
                                    icon: categoryIcon,
                                    childCount: 0,
                                    isExpanded: false,
                                    isChild: true,
                                    categoryColor: rootTint
                                ) {
                                    selectedCategory = child
                                } onLongPress: {
                                    selectedCategory = child
                                }
                                .padding(.leading, 36)
                                .padding(.trailing, 20)
                                .transition(.move(edge: .top).combined(with: .opacity))
                            }
                        }
                    }
                }
            }
        }
        // Bottom Sheet — детали категории
        .sheet(item: $selectedCategory) { item in
            CategoryDetailSheet(
                category: item,
                allCategories: allCategories,
                allTransactions: allTransactions,
                accentColor: accentColor,
                categoryIcon: categoryIcon,
                onAddSubcategory: {
                    addSubcategoryParent = item
                    selectedCategory = nil
                },
                onDeleted: { selectedCategory = nil }
            )
        }
        // Bottom Sheet — добавление подкатегории
        .sheet(item: $addSubcategoryParent) { parent in
            AddCategorySheet(parent: parent)
        }
    }
}

// MARK: - Строка категории

struct CategoryRow: View {
    let category: Category
    let accentColor: Color
    let icon: String
    let childCount: Int
    let isExpanded: Bool
    let isChild: Bool
    var categoryColor: Color? = nil
    let onTap: () -> Void
    let onLongPress: () -> Void

    var body: some View {
        let iconColor = categoryColor ?? accentColor
        return Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(isChild ? .body : .title3)
                    .foregroundStyle(iconColor)
                    .frame(width: isChild ? 32 : 40, height: isChild ? 32 : 40)
                    .background(iconColor.opacity(isChild ? 0.07 : 0.1))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(category.name)
                        .font(isChild ? .subheadline : .headline)
                        .foregroundStyle(.primary)
                    if !isChild && childCount > 0 {
                        Text("\(childCount) подкатегори\(childCount == 1 ? "я" : childCount < 5 ? "и" : "й")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if childCount > 0 {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.spring(response: 0.3), value: isExpanded)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(isChild ? 10 : 14)
            .cardStyle()
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5).onEnded { _ in onLongPress() }
        )
    }
}
