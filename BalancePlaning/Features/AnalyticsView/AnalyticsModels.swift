//
//  AnalyticsModels.swift
//  BalancePlaning
//

import SwiftUI

// MARK: - Модели данных для аналитики

struct CategoryExpenseGroup {
    let rootName: String
    let rootColor: Color?
    let total: Double
    let children: [(name: String, amount: Double)]
}

struct DayAmount: Identifiable {
    let id = UUID()
    let date: Date
    let amount: Double
    let kind: String
}
