//
//  DeletedRecord.swift
//  BalancePlaning
//
//  Tombstone: фиксирует факт удаления бизнес-объекта и синхронизируется в CloudKit.
//  Предотвращает воскрешение удалённых записей при следующей синхронизации другого устройства.
//

import Foundation
import SwiftData

@Model
final class DeletedRecord {
    /// UUID удалённого бизнес-объекта (Transaction.id, Account.id и т.д.)
    var deletedId: UUID = UUID()
    var deletedAt: Date = Date()
    /// userId бюджета, к которому принадлежал объект
    var userId: UUID = UUID()

    init(deletedId: UUID, userId: UUID) {
        self.deletedId = deletedId
        self.deletedAt = Date()
        self.userId    = userId
    }
}
