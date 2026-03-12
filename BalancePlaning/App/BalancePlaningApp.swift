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

    let container: ModelContainer = {
        let schema = Schema([User.self, Account.self, Category.self, Transaction.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Миграция не удалась — удаляем старое хранилище и создаём новое чистое
            print("SwiftData: не удалось открыть хранилище (\(error)). Создаём заново.")
            let storeURL = config.url
            try? FileManager.default.removeItem(at: storeURL)
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
            // После удаления пробуем ещё раз — теперь гарантированно чистая база
            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Не удалось создать ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
