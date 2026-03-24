//
//  CloudKitSyncService.swift
//  BalancePlaning
//

import Foundation
import CloudKit
import SwiftData

// MARK: - Константы

enum CloudKitConfig {
    static let containerID = "iCloud.com.akenory.BalancePlaning"
    static let zoneName    = "BudgetZone"

    /// Зона в private-базе текущего пользователя (владелец)
    static var ownerZoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
    }

    enum RecordType {
        static let account       = "BP_Account"
        static let accountGroup  = "BP_AccountGroup"
        static let category      = "BP_Category"
        static let transaction   = "BP_Transaction"
        static let loan          = "BP_Loan"
        static let loanPayment   = "BP_LoanPayment"
        static let currency      = "BP_Currency"
        static let deletedRecord = "BP_DeletedRecord"
    }
}

// MARK: - Ошибки

enum CloudKitError: Error, LocalizedError {
    case noShareURL
    case notSignedIn
    case zoneNotFound
    case noOwnerFound
    var errorDescription: String? {
        switch self {
        case .noShareURL:  return "Не удалось получить ссылку приглашения"
        case .notSignedIn: return "Войдите в iCloud в настройках устройства"
        case .zoneNotFound: return "Общий бюджет не найден"
        case .noOwnerFound: return "Не удалось определить владельца бюджета"
        }
    }
}

// MARK: - Сервис синхронизации

struct CloudKitSyncService {
    let context: ModelContext

    // Вычисляемый var — CKContainer создаётся только при первом реальном CloudKit-вызове,
    // а не при инициализации сервиса. Без этого краш если нет entitlements в Xcode.
    private var ckContainer: CKContainer { CKContainer(identifier: CloudKitConfig.containerID) }
    private var privateDB: CKDatabase { ckContainer.privateCloudDatabase }
    private var sharedDB:  CKDatabase { ckContainer.sharedCloudDatabase }

    // MARK: - Владелец: создаём зону + шару + загружаем данные

    func setupAndShare() async throws -> URL {
        // Проверяем статус iCloud
        let status = try await ckContainer.accountStatus()
        guard status == .available else { throw CloudKitError.notSignedIn }

        // 1. Создаём зону BudgetZone в private-базе
        let zone = CKRecordZone(zoneName: CloudKitConfig.zoneName)
        _ = try await privateDB.save(zone)

        // 2. Создаём zone-wide CKShare
        let zoneID = CloudKitConfig.ownerZoneID
        let share  = CKShare(recordZoneID: zoneID)
        share[CKShare.SystemFieldKey.title] = "Семейный бюджет"
        share.publicPermission = .readWrite

        let url = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<URL, Error>) in
            let op = CKModifyRecordsOperation(recordsToSave: [share])
            op.savePolicy = .allKeys
            op.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    if let url = share.url {
                        cont.resume(returning: url)
                    } else {
                        cont.resume(throwing: CloudKitError.noShareURL)
                    }
                case .failure(let error):
                    cont.resume(throwing: error)
                }
            }
            privateDB.add(op)
        }

        // 3. Загружаем локальные данные в созданную зону
        try await pushAllLocalData(to: zoneID, db: privateDB)

        return url
    }

    // MARK: - Участник: принимаем шару + загружаем данные в SwiftData

    func acceptShareAndSeed(url: URL) async throws -> (ownerId: UUID, ownerName: String) {
        let status = try await ckContainer.accountStatus()
        guard status == .available else { throw CloudKitError.notSignedIn }

        // 1. Получаем метаданные шары
        let metadata: CKShare.Metadata = try await withCheckedThrowingContinuation { cont in
            ckContainer.fetchShareMetadata(with: url) { meta, error in
                if let error { cont.resume(throwing: error) }
                else if let meta { cont.resume(returning: meta) }
                else { cont.resume(throwing: CloudKitError.zoneNotFound) }
            }
        }

        // 2. Принимаем приглашение
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            ckContainer.accept(metadata) { _, error in
                if let error { cont.resume(throwing: error) }
                else { cont.resume() }
            }
        }

        // 3. Находим зону BudgetZone в shared-базе
        let sharedZones = try await sharedDB.allRecordZones()
        guard let zone = sharedZones.first(where: { $0.zoneID.zoneName == CloudKitConfig.zoneName }) else {
            throw CloudKitError.zoneNotFound
        }

        // 4. Определяем имя владельца из метаданных
        let ownerName: String
        if let components = metadata.ownerIdentity.nameComponents {
            ownerName = PersonNameComponentsFormatter().string(from: components)
        } else {
            ownerName = "Совместный бюджет"
        }

        // 5. Засеиваем локальный SwiftData данными из шары
        let ownerId = try await seedLocalData(from: zone.zoneID, in: sharedDB)

        return (ownerId, ownerName)
    }

    // MARK: - Владелец: двусторонняя синхронизация

    /// Push: отправляет локальные данные владельца в CloudKit.
    /// Pull: забирает изменения, которые добавил участник (записал в ту же зону).
    func ownerFullSync() async throws {
        let status = try await ckContainer.accountStatus()
        guard status == .available else { throw CloudKitError.notSignedIn }
        let zoneID = CloudKitConfig.ownerZoneID
        // Push сначала: локальные изменения (в т.ч. новые поля) сохраняются в CloudKit
        // до того как pull может их перезаписать старыми данными из зоны.
        // Orphan-cleanup не используется — удаления распространяются через tombstone'ы,
        // что позволяет участникам добавлять записи без риска их удаления при push владельца.
        try await pushAllLocalData(to: zoneID, db: privateDB)
        // Pull: подтягиваем изменения участника (включая только что запушенные данные владельца)
        try await seedLocalData(from: zoneID, in: privateDB)
    }

    /// Быстрый push без pull — для авто-синхронизации при открытии приложения.
    func syncToCloud() async throws {
        let status = try await ckContainer.accountStatus()
        guard status == .available else { throw CloudKitError.notSignedIn }
        try await pushAllLocalData(to: CloudKitConfig.ownerZoneID, db: privateDB)
    }

    // MARK: - Участник: двусторонняя синхронизация

    /// Pull: скачивает свежие данные из шары → обновляет локальный SwiftData.
    /// Push: отправляет добавления участника обратно в зону владельца.
    func participantFullSync() async throws {
        let status = try await ckContainer.accountStatus()
        guard status == .available else { throw CloudKitError.notSignedIn }

        let sharedZones = try await sharedDB.allRecordZones()
        guard let zone = sharedZones.first(where: { $0.zoneID.zoneName == CloudKitConfig.zoneName }) else {
            throw CloudKitError.zoneNotFound
        }
        // Push сначала — сохраняем новые записи участника в облако до того, как pull их сотрёт локально
        try await pushParticipantData(to: zone.zoneID)
        // Pull — скачиваем актуальные данные (включая только что запушенные)
        try await seedLocalData(from: zone.zoneID, in: sharedDB)
    }

    /// Только pull — для авто-синхронизации при открытии.
    func syncFromCloud() async throws {
        let status = try await ckContainer.accountStatus()
        guard status == .available else { throw CloudKitError.notSignedIn }

        let sharedZones = try await sharedDB.allRecordZones()
        guard let zone = sharedZones.first(where: { $0.zoneID.zoneName == CloudKitConfig.zoneName }) else {
            throw CloudKitError.zoneNotFound
        }
        try await seedLocalData(from: zone.zoneID, in: sharedDB)
    }

    // MARK: - CloudKit подписки на изменения зоны

    func setupSubscriptions() async throws {
        let status = try await ckContainer.accountStatus()
        guard status == .available else { return }

        let budgetManager = SharedBudgetManager.shared
        let notifInfo = CKSubscription.NotificationInfo()
        notifInfo.shouldSendContentAvailable = true  // silent push

        if budgetManager.isParticipant {
            // Участник подписывается на изменения в shared-зоне
            let sharedZones = try await sharedDB.allRecordZones()
            guard let zone = sharedZones.first(where: { $0.zoneID.zoneName == CloudKitConfig.zoneName }) else { return }
            let sub = CKRecordZoneSubscription(zoneID: zone.zoneID, subscriptionID: "participant-budget-changes")
            sub.notificationInfo = notifInfo
            _ = try? await sharedDB.save(sub)
        } else if budgetManager.shareURL != nil {
            // Владелец подписывается на изменения в своей private-зоне
            let sub = CKRecordZoneSubscription(zoneID: CloudKitConfig.ownerZoneID, subscriptionID: "owner-budget-changes")
            sub.notificationInfo = notifInfo
            _ = try? await privateDB.save(sub)
        }
    }

    // MARK: - Остановить общий доступ (владелец)

    func stopSharing() async throws {
        let zoneID  = CloudKitConfig.ownerZoneID
        let shareID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zoneID)
        try await privateDB.deleteRecord(withID: shareID)
    }

    // MARK: - Private helpers

    /// Push для владельца: использует его собственный userId → private database
    private func pushAllLocalData(to zoneID: CKRecordZone.ID, db: CKDatabase) async throws {
        guard let userId = ownUserId() else { return }
        try await pushRecordsForUserId(userId, to: zoneID, db: db)
    }

    /// Push для участника: использует userId ВЛАДЕЛЬЦА → shared database.
    private func pushParticipantData(to zoneID: CKRecordZone.ID) async throws {
        guard let ownerId = SharedBudgetManager.shared.activeBudgetOwnerId else { return }
        try await pushRecordsForUserId(ownerId, to: zoneID, db: sharedDB)
    }

    private func pushRecordsForUserId(_ userId: UUID, to zoneID: CKRecordZone.ID, db: CKDatabase) async throws {
        var records: [CKRecord] = []

        if let arr = try? context.fetch(FetchDescriptor<Account>()) {
            records += arr.filter { $0.userId == userId }.map { $0.toCKRecord(zoneID: zoneID) }
        }
        if let arr = try? context.fetch(FetchDescriptor<AccountGroup>()) {
            records += arr.filter { $0.userId == userId }.map { $0.toCKRecord(zoneID: zoneID) }
        }
        if let arr = try? context.fetch(FetchDescriptor<Category>()) {
            records += arr.filter { $0.userId == userId }.map { $0.toCKRecord(zoneID: zoneID) }
        }
        if let arr = try? context.fetch(FetchDescriptor<Transaction>()) {
            records += arr.filter { $0.userId == userId }.map { $0.toCKRecord(zoneID: zoneID) }
        }
        if let arr = try? context.fetch(FetchDescriptor<Loan>()) {
            records += arr.filter { $0.userId == userId }.map { $0.toCKRecord(zoneID: zoneID) }
        }
        if let arr = try? context.fetch(FetchDescriptor<LoanPayment>()) {
            records += arr.filter { $0.userId == userId }.map { $0.toCKRecord(zoneID: zoneID) }
        }
        if let arr = try? context.fetch(FetchDescriptor<Currency>()) {
            records += arr.filter { $0.userId == userId }.map { $0.toCKRecord(zoneID: zoneID) }
        }
        // Локальные tombstone'ы — пушим их, чтобы другие устройства узнали об удалениях
        if let arr = try? context.fetch(FetchDescriptor<DeletedRecord>()) {
            records += arr.filter { $0.userId == userId }.map { $0.toCKRecord(zoneID: zoneID) }
        }

        let cloudRecords = try await fetchAllRecords(from: zoneID, in: db)

        // Tombstone'ы из CloudKit: другие устройства могли удалить записи до нас.
        // Фильтруем — не пушим то, что уже помечено к удалению в CloudKit.
        let cloudTombstonedIds = Set(
            cloudRecords
                .filter { $0.recordType == CloudKitConfig.RecordType.deletedRecord }
                .compactMap { $0["deletedId"] as? String }
                .compactMap { UUID(uuidString: $0) }
        )
        if !cloudTombstonedIds.isEmpty {
            records = records.filter { r in
                guard r.recordType != CloudKitConfig.RecordType.deletedRecord,
                      let idStr = r["id"] as? String, let id = UUID(uuidString: idStr)
                else { return true }
                return !cloudTombstonedIds.contains(id)
            }
        }

        // Дедупликация на случай нескольких tombstone'ов с одинаковым deletedId
        var seenNames = Set<String>()
        records = records.filter { seenNames.insert($0.recordID.recordName).inserted }

        if !records.isEmpty { try await batchSave(records, to: db) }
    }

    @discardableResult
    private func seedLocalData(from zoneID: CKRecordZone.ID, in db: CKDatabase) async throws -> UUID {
        let records = try await fetchAllRecords(from: zoneID, in: db)

        let ownerIdStr = records.compactMap { $0["userId"] as? String }.first
        guard let str = ownerIdStr, let ownerId = UUID(uuidString: str) else {
            throw CloudKitError.noOwnerFound
        }

        // Строим словари существующих локальных объектов владельца для O(1) поиска.
        // Используем upsert вместо clear+reinsert, чтобы SwiftUI-вьюхи не видели
        // zombie-объекты (detached backing data) во время merge после context.save().
        let localAccounts      = Dictionary(uniqueKeysWithValues:
            ((try? context.fetch(FetchDescriptor<Account>()))        ?? []).filter { $0.userId == ownerId }.map { ($0.id, $0) })
        let localGroups        = Dictionary(uniqueKeysWithValues:
            ((try? context.fetch(FetchDescriptor<AccountGroup>()))   ?? []).filter { $0.userId == ownerId }.map { ($0.id, $0) })
        let localCategories    = Dictionary(uniqueKeysWithValues:
            ((try? context.fetch(FetchDescriptor<Category>()))       ?? []).filter { $0.userId == ownerId }.map { ($0.id, $0) })
        let localLoans         = Dictionary(uniqueKeysWithValues:
            ((try? context.fetch(FetchDescriptor<Loan>()))           ?? []).filter { $0.userId == ownerId }.map { ($0.id, $0) })
        let localPayments      = Dictionary(uniqueKeysWithValues:
            ((try? context.fetch(FetchDescriptor<LoanPayment>()))    ?? []).filter { $0.userId == ownerId }.map { ($0.id, $0) })
        let localCurrencies    = Dictionary(uniqueKeysWithValues:
            ((try? context.fetch(FetchDescriptor<Currency>()))       ?? []).filter { $0.userId == ownerId }.map { ($0.id, $0) })
        let localTransactions  = Dictionary(uniqueKeysWithValues:
            ((try? context.fetch(FetchDescriptor<Transaction>()))    ?? []).filter { $0.userId == ownerId }.map { ($0.id, $0) })
        // uniquingKeysWith: дубли возможны если tombstone создавался дважды для одного объекта
        let localTombstones: [UUID: DeletedRecord] = {
            let all = ((try? context.fetch(FetchDescriptor<DeletedRecord>())) ?? []).filter { $0.userId == ownerId }
            // Удаляем дубли из хранилища, оставляем только первый
            var seen = Set<UUID>()
            for t in all {
                if seen.contains(t.deletedId) { context.delete(t) }
                else { seen.insert(t.deletedId) }
            }
            return Dictionary(all.map { ($0.deletedId, $0) }, uniquingKeysWith: { first, _ in first })
        }()

        // Tombstone'ы: UUID удалённых объектов.
        // Объединяем CloudKit-tombstone'ы (от других устройств) с локальными (ещё не отправленными).
        // Локальные tombstone'ы нужны при pull-first: защищают от воскрешения локально удалённых записей
        // даже до того, как tombstone был отправлен в CloudKit.
        let cloudTombstonedIds = Set(
            records
                .filter { $0.recordType == CloudKitConfig.RecordType.deletedRecord }
                .compactMap { $0["deletedId"] as? String }
                .compactMap { UUID(uuidString: $0) }
        )
        let tombstonedIds = cloudTombstonedIds.union(Set(localTombstones.keys))

        var seenAccounts:     Set<UUID> = []
        var seenGroups:       Set<UUID> = []
        var seenCategories:   Set<UUID> = []
        var seenLoans:        Set<UUID> = []
        var seenPayments:     Set<UUID> = []
        var seenCurrencies:   Set<UUID> = []
        var seenTransactions: Set<UUID> = []
        var seenTombstones:   Set<UUID> = []

        // Проход 1: всё кроме транзакций (upsert).
        // Tombstoned объекты пропускаем (и удаляем локальную копию, если есть).
        for r in records {
            guard let idStr = r["id"] as? String, let id = UUID(uuidString: idStr) else { continue }
            switch r.recordType {
            case CloudKitConfig.RecordType.account:
                if tombstonedIds.contains(id) { if let e = localAccounts[id] { context.delete(e) }; continue }
                seenAccounts.insert(id)
                if let existing = localAccounts[id] { existing.update(from: r) }
                else if let obj = Account(ckRecord: r) { context.insert(obj) }
            case CloudKitConfig.RecordType.accountGroup:
                if tombstonedIds.contains(id) { if let e = localGroups[id] { context.delete(e) }; continue }
                seenGroups.insert(id)
                if let existing = localGroups[id] { existing.update(from: r) }
                else if let obj = AccountGroup(ckRecord: r) { context.insert(obj) }
            case CloudKitConfig.RecordType.category:
                if tombstonedIds.contains(id) { if let e = localCategories[id] { context.delete(e) }; continue }
                seenCategories.insert(id)
                if let existing = localCategories[id] { existing.update(from: r) }
                else if let obj = Category(ckRecord: r) { context.insert(obj) }
            case CloudKitConfig.RecordType.loan:
                if tombstonedIds.contains(id) { if let e = localLoans[id] { context.delete(e) }; continue }
                seenLoans.insert(id)
                if let existing = localLoans[id] { existing.update(from: r) }
                else if let obj = Loan(ckRecord: r) { context.insert(obj) }
            case CloudKitConfig.RecordType.loanPayment:
                if tombstonedIds.contains(id) { if let e = localPayments[id] { context.delete(e) }; continue }
                seenPayments.insert(id)
                if let existing = localPayments[id] { existing.update(from: r) }
                else if let obj = LoanPayment(ckRecord: r) { context.insert(obj) }
            case CloudKitConfig.RecordType.currency:
                if tombstonedIds.contains(id) { if let e = localCurrencies[id] { context.delete(e) }; continue }
                seenCurrencies.insert(id)
                if let existing = localCurrencies[id] { existing.update(from: r) }
                else if let obj = Currency(ckRecord: r) { context.insert(obj) }
            case CloudKitConfig.RecordType.deletedRecord:
                // id здесь — deletedId из CKRecord, но для уникальности в словаре используем deletedId
                guard let didStr = r["deletedId"] as? String, let deletedId = UUID(uuidString: didStr) else { continue }
                seenTombstones.insert(deletedId)
                if localTombstones[deletedId] == nil, let obj = DeletedRecord(ckRecord: r) { context.insert(obj) }
            default: break
            }
        }

        // Удаляем только tombstoned объекты, которых нет в CloudKit.
        // Tombstone-only подход (как для транзакций выше): защищает только что созданные локальные
        // объекты от удаления — они ещё не попали в CloudKit, но tombstone'а на них нет.
        // Удаление без tombstone (orphan-cleanup) удаляло бы эти объекты сразу после создания.
        for (id, obj) in localAccounts   where tombstonedIds.contains(id) && !seenAccounts.contains(id)   { context.delete(obj) }
        for (id, obj) in localGroups     where tombstonedIds.contains(id) && !seenGroups.contains(id)     { context.delete(obj) }
        for (id, obj) in localCategories where tombstonedIds.contains(id) && !seenCategories.contains(id) { context.delete(obj) }
        for (id, obj) in localLoans      where tombstonedIds.contains(id) && !seenLoans.contains(id)      { context.delete(obj) }
        for (id, obj) in localPayments   where tombstonedIds.contains(id) && !seenPayments.contains(id)   { context.delete(obj) }
        for (id, obj) in localCurrencies where tombstonedIds.contains(id) && !seenCurrencies.contains(id) { context.delete(obj) }
        // Tombstone'ы накапливаются — намеренно не удаляем локальные tombstone'ы, которых нет в CloudKit

        // Проход 2: транзакции (upsert) — нужны актуальные Account/Category после прохода 1
        let accounts   = (try? context.fetch(FetchDescriptor<Account>()))   ?? []
        let categories = (try? context.fetch(FetchDescriptor<Category>())) ?? []

        for r in records where r.recordType == CloudKitConfig.RecordType.transaction {
            guard let idStr = r["id"] as? String, let id = UUID(uuidString: idStr) else { continue }
            if tombstonedIds.contains(id) { if let e = localTransactions[id] { context.delete(e) }; continue }
            seenTransactions.insert(id)
            if let existing = localTransactions[id] {
                existing.update(from: r, accounts: accounts, categories: categories)
            } else if let obj = Transaction(ckRecord: r, accounts: accounts, categories: categories) {
                context.insert(obj)
            }
        }

        // Для транзакций удаляем через orphan-cleanup ТОЛЬКО tombstoned-объекты.
        // Обычный "not in CloudKit" orphan-cleanup здесь намеренно не применяется:
        // он удалял бы только что созданные локальные транзакции, которые ещё не были запушены в CloudKit.
        // Удаление распространяется исключительно через tombstone-механизм.
        for (id, obj) in localTransactions where tombstonedIds.contains(id) && !seenTransactions.contains(id) {
            context.delete(obj)
        }

        // Один save в конце: все изменения применяются атомарно
        try? context.save()

        return ownerId
    }

    private func clearLocalData(for userId: UUID) {
        if let arr = try? context.fetch(FetchDescriptor<Account>()) {
            arr.filter { $0.userId == userId }.forEach { context.delete($0) }
        }
        if let arr = try? context.fetch(FetchDescriptor<AccountGroup>()) {
            arr.filter { $0.userId == userId }.forEach { context.delete($0) }
        }
        if let arr = try? context.fetch(FetchDescriptor<Category>()) {
            arr.filter { $0.userId == userId }.forEach { context.delete($0) }
        }
        if let arr = try? context.fetch(FetchDescriptor<Transaction>()) {
            arr.filter { $0.userId == userId }.forEach { context.delete($0) }
        }
        if let arr = try? context.fetch(FetchDescriptor<Loan>()) {
            arr.filter { $0.userId == userId }.forEach { context.delete($0) }
        }
        if let arr = try? context.fetch(FetchDescriptor<LoanPayment>()) {
            arr.filter { $0.userId == userId }.forEach { context.delete($0) }
        }
        if let arr = try? context.fetch(FetchDescriptor<Currency>()) {
            arr.filter { $0.userId == userId }.forEach { context.delete($0) }
        }
        // Не сохраняем здесь — итоговый save делается в конце seedLocalData.
        // Промежуточный save вызывал "backing data detached" краш в @Query-вьюхах.
    }

    private func fetchAllRecords(from zoneID: CKRecordZone.ID, in db: CKDatabase) async throws -> [CKRecord] {
        // CKFetchRecordZoneChangesOperation не требует queryable-полей в схеме,
        // в отличие от CKQuery. Получаем все записи зоны за один проход.
        try await withCheckedThrowingContinuation { cont in
            var records: [CKRecord] = []

            let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
            // serverChangeToken = nil → получаем все записи с самого начала
            config.previousServerChangeToken = nil

            let op = CKFetchRecordZoneChangesOperation(
                recordZoneIDs: [zoneID],
                configurationsByRecordZoneID: [zoneID: config]
            )

            op.recordWasChangedBlock = { _, result in
                if case .success(let record) = result { records.append(record) }
            }

            op.fetchRecordZoneChangesResultBlock = { result in
                switch result {
                case .success: cont.resume(returning: records)
                case .failure(let error): cont.resume(throwing: error)
                }
            }

            db.add(op)
        }
    }

    private func batchSave(_ records: [CKRecord], to db: CKDatabase) async throws {
        let batchSize = 400
        for start in stride(from: 0, to: records.count, by: batchSize) {
            let batch = Array(records[start ..< min(start + batchSize, records.count)])
            let (saveResults, _) = try await db.modifyRecords(
                saving: batch, deleting: [],
                savePolicy: .allKeys, atomically: false
            )
            for (_, result) in saveResults {
                if case .failure(let error) = result { throw error }
            }
        }
    }

    private func batchDelete(_ recordIDs: [CKRecord.ID], from db: CKDatabase) async throws {
        let batchSize = 400
        for start in stride(from: 0, to: recordIDs.count, by: batchSize) {
            let batch = Array(recordIDs[start ..< min(start + batchSize, recordIDs.count)])
            _ = try await db.modifyRecords(saving: [], deleting: batch, savePolicy: .allKeys, atomically: false)
        }
    }

    /// Удаляет из SwiftData все данные указанного владельца (при выходе участника)
    func deleteOwnerData(for ownerId: UUID) {
        clearLocalData(for: ownerId)
        try? context.save()
    }

    /// userId самого пользователя (игнорируя режим общего бюджета)
    private func ownUserId() -> UUID? {
        guard let s = UserDefaults.standard.string(forKey: UserDefaultKeys.currentUserId) else { return nil }
        return UUID(uuidString: s)
    }
}
