//
//  CategoryService.swift
//  BalancePlaning
//
//  Created by Дмитрий Дудник on 25.02.2026.
//

import Foundation
import SwiftData

class CategoryService {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Создание

    /// Создаёт корневую категорию
    func addCategory(categoryName: String, type: CategoryType, color: String = "", icon: String = "") {
        guard let userId = currentUserId() else {
            print("Нет текущего пользователя"); return
        }
        let newCategory = Category(id: UUID(), userId: userId, name: categoryName, type: type, color: color, icon: icon)
        context.insert(newCategory)
        save("Категория \(categoryName) создана")
    }

    /// Обновляет имя и/или родителя категории
    func updateCategory(_ category: Category, name: String, parentId: UUID?) {
        category.name = name
        category.parentId = parentId
        save()
    }

    /// Обновляет цвет категории
    func updateColor(_ category: Category, color: String) {
        category.color = color
        save()
    }

    /// Обновляет иконку категории
    func updateIcon(_ category: Category, icon: String) {
        category.icon = icon
        save()
    }

    /// Создаёт подкатегорию (глубина max 1: parent должен быть корневым)
    func addSubcategory(name: String, parent: Category) {
        guard parent.isRoot else {
            print("Нельзя создать подкатегорию у подкатегории (максимум 2 уровня)")
            return
        }
        guard let userId = currentUserId() else {
            print("Нет текущего пользователя"); return
        }
        let sub = Category(id: UUID(), userId: userId, name: name, type: parent.type, parentId: parent.id)
        context.insert(sub)
        save("Подкатегория \(name) создана")
    }

    // MARK: - Вспомогательные

    /// Прямые дети категории
    func children(of category: Category, all: [Category]) -> [Category] {
        all.filter { $0.parentId == category.id }
    }

    /// Все потомки (рекурсивно) — для каскадного удаления
    func allDescendants(of category: Category, all: [Category]) -> [Category] {
        let direct = children(of: category, all: all)
        return direct + direct.flatMap { allDescendants(of: $0, all: all) }
    }

    /// Находит родителя категории
    func parent(of category: Category, all: [Category]) -> Category? {
        guard let parentId = category.parentId else { return nil }
        return all.first { $0.id == parentId }
    }

    /// Находит или создаёт системную категорию «Неизвестно» для типа
    @discardableResult
    func getOrCreateDefaultCategory(type: CategoryType, all: [Category]) -> Category {
        guard let userId = currentUserId() else {
            fatalError("Нет текущего пользователя")
        }
        if let existing = all.first(where: { $0.userId == userId && $0.type == type && $0.isDefault }) {
            return existing
        }
        let defaultCat = Category(id: UUID(), userId: userId, name: "Неизвестно", type: type, isDefault: true)
        context.insert(defaultCat)
        save("Создана дефолтная категория «Неизвестно» (\(type.displayName))")
        return defaultCat
    }

    // MARK: - Удаление

    /// Удаляет категорию и всё её поддерево.
    /// - deleteTransactions: true → удалить связанные транзакции,
    ///                        false → перенести их в категорию «Неизвестно»
    func deleteCategory(
        _ category: Category,
        allCategories: [Category],
        allTransactions: [Transaction],
        deleteTransactions: Bool
    ) {
        guard !category.isDefault else {
            print("Системную категорию «Неизвестно» нельзя удалить")
            return
        }

        // Собираем всё поддерево (сама категория + потомки)
        let descendants = allDescendants(of: category, all: allCategories)
        let toDelete: [Category] = [category] + descendants
        let toDeleteIds = Set(toDelete.map { $0.id })

        // Обрабатываем транзакции
        let affected = allTransactions.filter { t in
            (t.fromCategory.map { toDeleteIds.contains($0.id) } ?? false) ||
            (t.toCategory.map   { toDeleteIds.contains($0.id) } ?? false)
        }

        let existingTombstones = (try? context.fetch(FetchDescriptor<DeletedRecord>())) ?? []
        let tombstonedIds = Set(existingTombstones.map { $0.deletedId })

        if deleteTransactions {
            for t in affected {
                if !tombstonedIds.contains(t.id) {
                    context.insert(DeletedRecord(deletedId: t.id, userId: t.userId))
                }
                context.delete(t)
            }
        } else {
            let defaultExpense = toDelete.contains(where: { $0.type == .expense })
                ? getOrCreateDefaultCategory(type: .expense, all: allCategories)
                : nil
            let defaultIncome  = toDelete.contains(where: { $0.type == .income })
                ? getOrCreateDefaultCategory(type: .income, all: allCategories)
                : nil

            for t in affected {
                if let fc = t.fromCategory, toDeleteIds.contains(fc.id) {
                    t.fromCategory = defaultIncome
                }
                if let tc = t.toCategory, toDeleteIds.contains(tc.id) {
                    t.toCategory = defaultExpense
                }
            }
        }

        // Удаляем всё поддерево с tombstone'ами
        for cat in toDelete {
            if !tombstonedIds.contains(cat.id) {
                context.insert(DeletedRecord(deletedId: cat.id, userId: cat.userId))
            }
            context.delete(cat)
        }
        save("Категория «\(category.name)» и её поддерево удалены")
    }

    // MARK: - Отображение в пикерах (статические хелперы для View)

    /// Возвращает категории в порядке дерева: корень → его дети, затем следующий корень
    static func sortedTree(from categories: [Category]) -> [Category] {
        let roots = categories.filter { $0.isRoot }.sorted { $0.name < $1.name }
        return roots.flatMap { root in
            [root] + categories.filter { $0.parentId == root.id }.sorted { $0.name < $1.name }
        }
    }

    /// Метка для пикера: подкатегории отображаются с отступом
    static func displayLabel(for category: Category) -> String {
        category.isRoot ? category.name : "    ↳ \(category.name)"
    }

    /// Breadcrumb для выбранного значения: «Продукты / Молоко» или просто «Продукты»
    static func breadcrumb(for category: Category, in all: [Category]) -> String {
        guard let parentId = category.parentId,
              let parent = all.first(where: { $0.id == parentId }) else {
            return category.name
        }
        return "\(parent.name) / \(category.name)"
    }

    // MARK: - Private

    private func save(_ message: String = "") {
        do {
            try context.save()
            if !message.isEmpty { print(message) }
        } catch {
            print("Ошибка сохранения: \(error)")
        }
    }
}
