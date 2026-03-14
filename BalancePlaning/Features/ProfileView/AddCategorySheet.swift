//
//  AddCategorySheet.swift
//  BalancePlaning
//

import SwiftUI
import SwiftData

// MARK: - Лист добавления категории / подкатегории

struct AddCategorySheet: View {
    /// Если nil — создаём корневую категорию; если задан — создаём подкатегорию
    let parent: Category?

    @Binding var type: CategoryType

    @State private var name: String = ""
    @State private var selectedColor: String = ""
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

                    // Выбор цвета для корневой категории
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Цвет категории")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                Button {
                                    selectedColor = ""
                                } label: {
                                    let selected = selectedColor.isEmpty
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
                                        selectedColor = swatch.hex
                                    } label: {
                                        let selected = selectedColor == swatch.hex
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
                }

                Button("Добавить") {
                    guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    let service = CategoryService(context: context)
                    if let p = parent {
                        service.addSubcategory(name: name, parent: p)
                    } else {
                        service.addCategory(categoryName: name, type: type, color: selectedColor)
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
