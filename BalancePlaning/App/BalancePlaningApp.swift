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
        let schema = Schema([User.self, Account.self, AccountGroup.self, Category.self, Transaction.self, Currency.self, Loan.self, LoanPayment.self])
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

    @StateObject private var settings = AppSettings.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .preferredColorScheme(settings.theme.colorScheme)
                .environment(\.locale, settings.locale)
                // Полная перестройка иерархии при смене языка — переводы подхватываются свежими Text
                .id(settings.language.rawValue)
                .onAppear {
                    // Восстанавливаем расписание уведомлений после перезапуска
                    NotificationService.rescheduleIfNeeded()
                }
        }
        .modelContainer(container)
    }
}
