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

    @State private var editName: String
    @State private var selectedParentId: UUID?
    @State private var showNameError = false
    @State private var showDeleteDialog = false

    init(category: Category, allCategories: [Category], allTransactions: [Transaction],
         accentColor: Color, categoryIcon: String,
         onAddSubcategory: @escaping () -> Void, onDeleted: @escaping () -> Void) {
        self.category = category
        self.allCategories = allCategories
        self.allTransactions = allTransactions
        self.accentColor = accentColor
        self.categoryIcon = categoryIcon
        self.onAddSubcategory = onAddSubcategory
        self.onDeleted = onDeleted
        _editName = State(initialValue: category.name)
        _selectedParentId = State(initialValue: category.parentId)
    }

    private var service: CategoryService { CategoryService(context: context) }

    private var children: [Category] {
        allCategories.filter { $0.parentId == category.id }
    }

    private var currentParentName: String? {
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

    // Доступные родительские категории того же типа, кроме себя
    private var availableParents: [Category] {
        guard let uid = currentUserId() else { return [] }
        return allCategories
            .filter { $0.isRoot && $0.type == category.type && $0.userId == uid && $0.id != category.id }
            .sorted { $0.name < $1.name }
    }

    // Показывать пикер родителя:
    // - подкатегория: всегда (смена родителя или стать корневой)
    // - корневая без детей: может стать подкатегорией другой
    private var showParentPicker: Bool {
        !category.isDefault && (!category.isRoot || children.isEmpty)
    }

    private var selectedParentName: String {
        if let pid = selectedParentId {
            return allCategories.first { $0.id == pid }?.name ?? "—"
        }
        return AppSettings.shared.bundle.localizedString(forKey: "Корневая категория", value: "Корневая категория", table: nil)
    }

    private var hasChanges: Bool {
        editName.trimmingCharacters(in: .whitespaces) != category.name ||
        selectedParentId != category.parentId
    }

    private var subcategoryCountLabel: String {
        let bundle = AppSettings.shared.bundle
        let n = children.count
        if bundle != Bundle.main {
            return "\(n) subcategor\(n == 1 ? "y" : "ies")"
        }
        let suffix = n == 1 ? "я" : n < 5 ? "и" : "й"
        return "\(n) подкатегори\(suffix)"
    }

    private var transactionCountLabel: String {
        let bundle = AppSettings.shared.bundle
        let n = affectedTransactionsCount
        if bundle != Bundle.main {
            return "\(n) transaction\(n == 1 ? "" : "s")"
        }
        let suffix: String
        if n == 1 { suffix = "я" } else if n < 5 { suffix = "и" } else { suffix = "й" }
        return "\(n) операци\(suffix)"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {

                // Drag indicator
                Capsule()
                    .fill(Color.secondary.opacity(0.4))
                    .frame(width: 40, height: 4)
                    .padding(.top, 12)
                    .padding(.bottom, 20)

                // Иконка
                Image(systemName: category.icon.isEmpty ? categoryIcon : category.icon)
                    .font(.system(size: 44))
                    .foregroundStyle(accentColor)
                    .padding(.bottom, 8)

                // Путь
                if let pName = currentParentName {
                    Text("\(pName) → \(category.name)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 2)
                }

                Text(category.name)
                    .font(.title2.bold())

                Text(LocalizedStringKey(category.type.displayName))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)

                // Статистика
                HStack(spacing: 24) {
                    if !children.isEmpty {
                        Label(subcategoryCountLabel, systemImage: "folder")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if affectedTransactionsCount > 0 {
                        Label(transactionCountLabel, systemImage: "arrow.left.arrow.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 24)

                // MARK: Редактирование (не для системных)
                if !category.isDefault {
                    VStack(spacing: 0) {
                        // Название
                        HStack(spacing: 12) {
                            Image(systemName: "pencil")
                                .foregroundStyle(accentColor)
                                .frame(width: 20)
                            TextField("Название", text: $editName)
                                .foregroundStyle(showNameError ? .red : .primary)
                                .onChange(of: editName) { _, _ in showNameError = false }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)

                        // Родительская категория
                        if showParentPicker {
                            Divider().padding(.leading, 48)
                            Menu {
                                Button {
                                    selectedParentId = nil
                                } label: {
                                    Label("Корневая категория", systemImage: "folder")
                                }
                                if !availableParents.isEmpty {
                                    Divider()
                                    ForEach(availableParents) { parent in
                                        Button {
                                            selectedParentId = parent.id
                                        } label: {
                                            Label(parent.name, systemImage: "folder.fill")
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "folder.badge.questionmark")
                                        .foregroundStyle(accentColor)
                                        .frame(width: 20)
                                    Text("Раздел")
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Text(selectedParentName)
                                        .foregroundStyle(.secondary)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 16).padding(.vertical, 14)
                            }
                        }
                    }
                    .cardStyle()
                    .padding(.horizontal)
                    .padding(.bottom, 12)

                    if hasChanges {
                        Button {
                            saveChanges()
                        } label: {
                            Text("Сохранить изменения")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(accentColor)
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                    }
                }

                // Выбор иконки (только для корневых не-дефолтных)
                if category.isRoot && !category.isDefault {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Иконка")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                        IconPickerView(
                            selectedIcon: Binding(
                                get: { category.icon },
                                set: { service.updateIcon(category, icon: $0) }
                            ),
                            icons: IconPalette.categoryIcons,
                            accentColor: CategoryColors.resolve(category.color) ?? accentColor
                        )
                    }
                    .padding(.bottom, 8)
                }

                // Выбор цвета (только для корневых не-дефолтных)
                if category.isRoot && !category.isDefault {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Цвет категории")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
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
        }
        .presentationDetents([.large])
        .confirmationDialog(deleteDialogTitle, isPresented: $showDeleteDialog, titleVisibility: .visible) {
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

    private func saveChanges() {
        let trimmed = editName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { showNameError = true; return }
        service.updateCategory(category, name: trimmed, parentId: selectedParentId)
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
