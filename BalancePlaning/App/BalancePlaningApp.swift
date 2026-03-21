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

    // Phase 2: AppDelegate для обработки silent CloudKit push
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @Environment(\.scenePhase) private var scenePhase

    let container: ModelContainer = {
        let schema = Schema([
            User.self, Account.self, AccountGroup.self,
            Category.self, Transaction.self, Currency.self,
            Loan.self, LoanPayment.self, DeletedRecord.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            print("SwiftData: не удалось открыть хранилище (\(error)). Создаём заново.")
            let storeURL = config.url
            try? FileManager.default.removeItem(at: storeURL)
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Не удалось создать ModelContainer: \(error)")
            }
        }
    }()

    @StateObject private var settings      = AppSettings.shared
    @StateObject private var budgetManager = SharedBudgetManager.shared
    @StateObject private var autoSync      = CloudKitAutoSyncManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(budgetManager)
                .environmentObject(autoSync)
                .preferredColorScheme(settings.theme.colorScheme)
                .environment(\.locale, settings.locale)
                .id(settings.language.rawValue)
                .onAppear {
                    NotificationService.rescheduleIfNeeded()
                    // CloudKit запускаем только если пользователь уже включил общий бюджет.
                    // Без entitlements в Xcode CKContainer(identifier:) крашит приложение,
                    // поэтому не инициализируем CloudKit при обычном запуске.
                    let bm = SharedBudgetManager.shared
                    if bm.isParticipant || bm.shareURL != nil {
                        let sync = CloudKitAutoSyncManager.shared
                        sync.configure(with: container)
                        sync.scheduleSync()
                        sync.startPolling()
                    }
                }
                // Поллинг: запускаем при активном состоянии, останавливаем в фоне
                .onChange(of: scenePhase) { _, newPhase in
                    let sync = CloudKitAutoSyncManager.shared
                    let bm   = SharedBudgetManager.shared
                    switch newPhase {
                    case .active:
                        if bm.isParticipant || bm.shareURL != nil {
                            sync.scheduleSync()
                            sync.startPolling()
                        }
                    case .background, .inactive:
                        sync.stopPolling()
                    default:
                        break
                    }
                }
                // Обработка ссылки-приглашения при открытии приложения
                .onOpenURL { url in
                    handleIncomingShareURL(url)
                }
        }
        .modelContainer(container)
    }

    // MARK: - CloudKit Share URL

    private func handleIncomingShareURL(_ url: URL) {
        guard url.host?.contains("icloud.com") == true ||
              url.scheme == "cloudkit-icloud" else { return }
        NotificationCenter.default.post(
            name: .cloudKitShareInvitationReceived,
            object: nil,
            userInfo: ["url": url]
        )
    }
}

// MARK: - Notification name

extension Notification.Name {
    static let cloudKitShareInvitationReceived = Notification.Name("cloudKitShareInvitationReceived")
}
