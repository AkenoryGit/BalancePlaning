//
//  CloudKitAutoSyncManager.swift
//  BalancePlaning
//
//  Phase 2: автоматическая фоновая синхронизация с CloudKit.
//  Запускается при выходе приложения на передний план и по silent push-уведомлению.
//

import Foundation
import Combine
import SwiftData

@MainActor
class CloudKitAutoSyncManager: ObservableObject {

    static let shared = CloudKitAutoSyncManager()

    @Published var isSyncing       = false
    @Published var lastSyncError:    String?
    @Published var lastSyncDate:     Date?

    private var modelContainer: ModelContainer?
    private var pendingSyncTask: Task<Void, Never>?
    private var contextSaveCancellable: AnyCancellable?
    private var pollingTask: Task<Void, Never>?

    /// Минимальный интервал между авто-синхронизациями (секунды)
    private let minIntervalSeconds: TimeInterval = 60
    /// Интервал фонового поллинга пока приложение на переднем плане
    private let pollingIntervalSeconds: UInt64 = 30

    private init() {}

    // MARK: - Setup

    /// Вызывается один раз при старте приложения из BalancePlaningApp
    func configure(with container: ModelContainer) {
        modelContainer = container
        // Регистрируемся для remote push только здесь — когда sharing реально используется
        AppDelegate.registerForPush()
        // Регистрируем CloudKit-подписки после инициализации
        Task { await registerSubscriptions() }
        // Авто-синхронизация после любого context.save() — через CoreData-уведомление
        // Имя уведомления — строковой эквивалент NSManagedObjectContext.didSaveNotification
        contextSaveCancellable = NotificationCenter.default
            .publisher(for: Notification.Name("NSManagedObjectContextDidSave"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, !self.isSyncing else { return }
                self.scheduleSync()
            }
    }

    // MARK: - Polling

    /// Запускает синхронизацию каждые 30 секунд пока приложение активно
    func startPolling() {
        guard SharedBudgetManager.shared.isParticipant || SharedBudgetManager.shared.shareURL != nil else { return }
        stopPolling()
        pollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: pollingIntervalSeconds * 1_000_000_000)
                guard !Task.isCancelled else { return }
                await performSync(force: true)
            }
        }
    }

    /// Останавливает поллинг (при уходе в фон)
    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    // MARK: - Public API

    /// Запустить синхронизацию с дебаунсом 2 с (для авто-триггеров)
    func scheduleSync() {
        pendingSyncTask?.cancel()
        pendingSyncTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            await performSync()
        }
    }

    /// Немедленная синхронизация без дебаунса (по кнопке или push)
    func syncNow() {
        Task { await performSync(force: true) }
    }

    /// Async-версия для pull-to-refresh: ожидает завершения синхронизации и выполняет свой синк
    func syncNowAsync() async {
        pendingSyncTask?.cancel()
        guard let container = modelContainer else { return }
        let budgetManager = SharedBudgetManager.shared
        guard budgetManager.isParticipant || budgetManager.shareURL != nil else { return }

        // Ждём завершения текущего синка (например, поллинга)
        while isSyncing {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        isSyncing     = true
        lastSyncError = nil

        let syncContext = ModelContext(container)
        syncContext.autosaveEnabled = false
        let service = CloudKitSyncService(context: syncContext)

        do {
            if budgetManager.isParticipant {
                try await service.participantFullSync()
            } else {
                try await service.ownerFullSync()
            }
            lastSyncDate = Date()
        } catch {
            lastSyncError = error.localizedDescription
        }

        // Даём @Query один цикл run loop чтобы обработать merge-нотификацию
        // и обновить кеш до того, как isSyncing = false спровоцирует ре-рендер вьюх.
        await Task.yield()
        isSyncing = false
    }

    // MARK: - Core sync

    private func performSync(force: Bool = false) async {
        guard let container = modelContainer else { return }
        guard !isSyncing else { return }

        // Throttle: не синхронизируем чаще minIntervalSeconds
        if !force, let last = lastSyncDate,
           Date().timeIntervalSince(last) < minIntervalSeconds { return }

        let budgetManager = SharedBudgetManager.shared
        // Нет активного общего бюджета — синхронизировать нечего
        guard budgetManager.isParticipant || budgetManager.shareURL != nil else { return }

        isSyncing     = true
        lastSyncError = nil

        // Используем отдельный контекст вместо mainContext.
        // seedLocalData использует upsert (update in place), а не clear+reinsert,
        // поэтому @Query-вьюхи не получают zombie-объекты (detached backing data).
        let syncContext = ModelContext(container)
        syncContext.autosaveEnabled = false
        let service = CloudKitSyncService(context: syncContext)

        do {
            if budgetManager.isParticipant {
                // Участник: сначала push (чтобы локальные изменения не потерялись),
                // потом pull. Только pull без push приводил к тому, что созданные
                // участником данные удалялись clearLocalData до того, как попали в CloudKit.
                try await service.participantFullSync()
            } else {
                // Владелец: push + pull чтобы видеть изменения участника
                try await service.ownerFullSync()
            }
            lastSyncDate = Date()
        } catch {
            lastSyncError = error.localizedDescription
        }

        // Даём @Query один цикл run loop чтобы обработать merge-нотификацию
        // и обновить кеш до того, как isSyncing = false спровоцирует ре-рендер вьюх.
        await Task.yield()
        isSyncing = false
    }

    // MARK: - CloudKit subscriptions

    private func registerSubscriptions() async {
        guard let container = modelContainer else { return }
        let service = CloudKitSyncService(context: ModelContext(container))
        try? await service.setupSubscriptions()
    }
}
