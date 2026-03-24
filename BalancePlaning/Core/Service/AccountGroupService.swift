//
//  AccountGroupService.swift
//  BalancePlaning
//

import Foundation
import SwiftData

struct AccountGroupService {
    let context: ModelContext

    func addGroup(name: String, color: String = "") {
        guard let userId = currentUserId() else { return }
        let group = AccountGroup(userId: userId, name: name, color: color)
        context.insert(group)
        try? context.save()
    }

    func updateGroup(_ group: AccountGroup, name: String, color: String = "") {
        group.name = name
        group.color = color
        try? context.save()
    }

    func deleteGroup(_ group: AccountGroup) {
        guard let userId = currentUserId() else { return }
        let predicate = #Predicate<Account> { $0.userId == userId }
        let descriptor = FetchDescriptor<Account>(predicate: predicate)
        if let accounts = try? context.fetch(descriptor) {
            for account in accounts where account.groupId == group.id {
                account.groupId = nil
            }
        }
        let existing = (try? context.fetch(FetchDescriptor<DeletedRecord>())) ?? []
        if !existing.contains(where: { $0.deletedId == group.id }) {
            context.insert(DeletedRecord(deletedId: group.id, userId: group.userId))
        }
        context.delete(group)
        try? context.save()
    }
}
