//
//  BalancePlaningApp.swift
//  BalancePlaning
//
//  Created by Дмитрий Дудник on 04.02.2026.
//

import SwiftUI
import SwiftData

@main
struct BalancePlaningApp: App {

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [User.self, Account.self, Category.self, Transaction.self]) // контейнер с данными хранится в корне приложения
    }
}
