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

                    VStack(spacing: 4) {
                        // Строка корневой категории
                        CategoryRow(
                            category: root,
                            accentColor: accentColor,
                            icon: categoryIcon,
                            childCount: children.count,
                            isExpanded: isExpanded,
                            isChild: false
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
                                    isChild: true
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
    let onTap: () -> Void
    let onLongPress: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(isChild ? .body : .title3)
                    .foregroundStyle(accentColor)
                    .frame(width: isChild ? 32 : 40, height: isChild ? 32 : 40)
                    .background(accentColor.opacity(isChild ? 0.07 : 0.1))
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

// MARK: - Bottom Sheet с деталями категории

struct CategoryDetailSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss)      private var dismiss

    let category: Category
    let allCategories: [Category]
    let allTransactions: [Transaction]
    let accentColor: Color
    let categoryIcon: String
    let onAddSubcategory: () -> Void
    let onDeleted: () -> Void

    @State private var showDeleteDialog = false

    private var service: CategoryService { CategoryService(context: context) }

    private var children: [Category] {
        allCategories.filter { $0.parentId == category.id }
    }

    private var parentName: String? {
        guard let pid = category.parentId else { return nil }
        return allCategories.first { $0.id == pid }?.name
    }

    // Транзакции, затронутые удалением (вся ветка)
    private var affectedTransactionsCount: Int {
        let ids = Set(([category] + service.allDescendants(of: category, all: allCategories)).map { $0.id })
        return allTransactions.filter { t in
            (t.fromCategory.map { ids.contains($0.id) } ?? false) ||
            (t.toCategory.map   { ids.contains($0.id) } ?? false)
        }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 40, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 20)

            // Иконка
            Image(systemName: categoryIcon)
                .font(.system(size: 44))
                .foregroundStyle(accentColor)
                .padding(.bottom, 8)

            // Путь
            if let pName = parentName {
                Text("\(pName) → \(category.name)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 2)
            }

            Text(category.name)
                .font(.title2.bold())

            Text(category.type.displayName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            // Статистика
            HStack(spacing: 24) {
                if !children.isEmpty {
                    Label("\(children.count) подкат.", systemImage: "folder")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if affectedTransactionsCount > 0 {
                    Label("\(affectedTransactionsCount) операций", systemImage: "arrow.left.arrow.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 28)

            VStack(spacing: 12) {
                // Кнопка добавить подкатегорию (только для корневых)
                if category.isRoot {
                    Button(action: onAddSubcategory) {
                        Label("Добавить подкатегорию", systemImage: "folder.badge.plus")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.bordered)
                    .tint(accentColor)
                    .padding(.horizontal)
                }

                // Кнопка удалить (не для дефолтных)
                if !category.isDefault {
                    Button(role: .destructive) {
                        showDeleteDialog = true
                    } label: {
                        Label("Удалить категорию", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .padding(.horizontal)
                } else {
                    Text("Системная категория — нельзя удалить")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }
            }
            .padding(.bottom, 32)
        }
        .presentationDetents([.medium])
        .confirmationDialog(deleteDialogTitle, isPresented: $showDeleteDialog, titleVisibility: .visible) {
            // Удалить всё (категории + транзакции)
            Button("Удалить всё, включая операции (\(affectedTransactionsCount))", role: .destructive) {
                service.deleteCategory(
                    category,
                    allCategories: allCategories,
                    allTransactions: allTransactions,
                    deleteTransactions: true
                )
                onDeleted()
                dismiss()
            }

            // Удалить категории, операции → «Неизвестно»
            if affectedTransactionsCount > 0 {
                Button("Удалить категории, операции в «Неизвестно»", role: .destructive) {
                    service.deleteCategory(
                        category,
                        allCategories: allCategories,
                        allTransactions: allTransactions,
                        deleteTransactions: false
                    )
                    onDeleted()
                    dismiss()
                }
            }

            Button("Отмена", role: .cancel) {}
        } message: {
            Text(deleteDialogMessage)
        }
    }

    private var deleteDialogTitle: String {
        "Удалить «\(category.name)»?"
    }

    private var deleteDialogMessage: String {
        var parts: [String] = []
        if !children.isEmpty {
            parts.append("Вместе с ней будут удалены \(children.count) подкатегори\(children.count == 1 ? "я" : children.count < 5 ? "и" : "й").")
        }
        if affectedTransactionsCount > 0 {
            parts.append("Затронуто операций: \(affectedTransactionsCount).")
        }
        return parts.joined(separator: " ")
    }
}

// MARK: - Лист добавления категории / подкатегории

struct AddCategorySheet: View {
    /// Если nil — создаём корневую категорию; если задан — создаём подкатегорию
    let parent: Category?

    @Binding var type: CategoryType

    @State private var name: String = ""
    @Environment(\.dismiss)      private var dismiss
    @Environment(\.modelContext) private var context

    /// Вызывается из ProfileView для создания корневой категории
    init(type: Binding<CategoryType>) {
        self.parent = nil
        self._type = type
    }

    /// Вызывается из CategoriesView для создания подкатегории
    init(parent: Category) {
        self.parent = parent
        self._type = .constant(parent.type)
    }

    private var isSubcategory: Bool { parent != nil }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(isSubcategory ? "Новая подкатегория" : "Новая категория")
                    .font(.title2.bold())

                if let p = parent {
                    Label("В категории «\(p.name)»", systemImage: "folder")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                TextField("Название", text: $name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)

                // Тип показываем только для корневых
                if !isSubcategory {
                    Picker("Тип", selection: $type) {
                        Text("Расход").tag(CategoryType.expense)
                        Text("Доход").tag(CategoryType.income)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                }

                Button("Добавить") {
                    guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    let service = CategoryService(context: context)
                    if let p = parent {
                        service.addSubcategory(name: name, parent: p)
                    } else {
                        service.addCategory(categoryName: name, type: type)
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)

                Button("Отмена") { dismiss() }
                    .foregroundStyle(.secondary)
            }
            .padding()
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }
}
