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
    
    func addCategory(categoryName: String, type: CategoryType) {
        guard let uuidString = currentUserId() else {
            print("Нет текущего пользователя")
            return
        }
        let newCategory = Category(id: UUID(), userId: uuidString, name: categoryName, type: type)
        
        context.insert(newCategory)
        
        do {
            try context.save()
            print("Категория \(newCategory.name) была успешно создана!")
        } catch {
            print("Ошибка создания категории: \(error)")
            context.delete(newCategory)
        }
    }
    
    func deleteCategory(_ category: Category) {
        context.delete(category)
        
        do {
            try context.save()
            print("Категория \(category) была успешно удалена!")
        } catch {
            print("Ошибка удаления категории: \(error)")
        }
    }
}
