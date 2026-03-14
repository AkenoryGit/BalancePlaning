//
//  CategoryDetailSheet.swift
//  BalancePlaning
//

import SwiftUI
import SwiftData

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

            // Выбор цвета (только для корневых не-дефолтных)
            if category.isRoot && !category.isDefault {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Цвет категории")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            // Кнопка «без цвета»
                            Button {
                                service.updateColor(category, color: "")
                            } label: {
                                let selected = category.color.isEmpty
                                ZStack {
                                    Circle()
                                        .stroke(Color.secondary.opacity(0.4), lineWidth: 1.5)
                                        .frame(width: 28, height: 28)
                                    Image(systemName: "xmark")
                                        .font(.caption.bold())
                                        .foregroundStyle(.secondary)
                                }
                                .overlay(selected ? Circle().stroke(Color.primary, lineWidth: 2.5) : nil)
                                .scaleEffect(selected ? 1.2 : 1.0)
                                .animation(.spring(response: 0.25), value: selected)
                            }

                            ForEach(CategoryColors.palette) { swatch in
                                Button {
                                    service.updateColor(category, color: swatch.hex)
                                } label: {
                                    let selected = category.color == swatch.hex
                                    Circle()
                                        .fill(swatch.color)
                                        .frame(width: 28, height: 28)
                                        .overlay(selected ? Circle().stroke(Color.primary, lineWidth: 2.5) : nil)
                                        .scaleEffect(selected ? 1.2 : 1.0)
                                        .animation(.spring(response: 0.25), value: selected)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                }
                .padding(.bottom, 8)
            }

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
