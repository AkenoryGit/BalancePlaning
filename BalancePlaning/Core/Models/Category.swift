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
    
    init(id: UUID = UUID(), userId: UUID, name: String, type: CategoryType) {
            self.id = id
            self.userId = userId
            self.name = name
            self.type = type
        }
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
