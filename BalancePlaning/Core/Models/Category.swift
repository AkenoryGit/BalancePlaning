//
//  Category.swift
//  BalancePlaning
//
//  Created by Дмитрий Дудник on 25.02.2026.
//

import Foundation
import SwiftData

@Model
class Category {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var name: String
    var type: CategoryType
    /// nil = корневая категория; UUID = подкатегория (глубина max 1)
    var parentId: UUID? = nil
    /// Системная категория «Неизвестно» — нельзя удалить
    var isDefault: Bool = false
    /// Цвет категории в формате hex (напр. "FF4B4B"); пусто = нет цвета
    var color: String = ""
    /// SF Symbol name для иконки; пусто = иконка по умолчанию
    var icon: String = ""

    init(
        id: UUID = UUID(),
        userId: UUID,
        name: String,
        type: CategoryType,
        parentId: UUID? = nil,
        isDefault: Bool = false,
        color: String = "",
        icon: String = ""
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.type = type
        self.parentId = parentId
        self.isDefault = isDefault
        self.color = color
        self.icon = icon
    }

    /// true, если категория является корневой (не подкатегория)
    var isRoot: Bool { parentId == nil }
}

enum CategoryType: String, Codable {
    case income = "income"
    case expense = "expense"

    var displayName: String {
        switch self {
        case .income: return "Доход"
        case .expense: return "Расход"
        }
    }
}
