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

struct MonthSummary: Identifiable {
    let id = UUID()
    let month: Date
    let income: Double
    let expense: Double
}

struct MonthBar: Identifiable {
    let id = UUID()
    let month: Date
    let amount: Double
    let kind: String // "Доходы" или "Расходы"
}
