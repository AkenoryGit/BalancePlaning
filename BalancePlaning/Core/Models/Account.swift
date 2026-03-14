//
//  Account.swift
//  BalancePlaning
//
//  Created by Дмитрий Дудник on 12.02.2026.
//

import Foundation
import SwiftData

@Model
class Account {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var name: String
    var balance: Decimal
    var groupId: UUID? = nil
    var currency: String = "RUB"
    var isIncludedInBalance: Bool = true

    init(id: UUID = UUID(), userId: UUID, name: String, balance: Decimal, groupId: UUID? = nil, currency: String = "RUB") {
        self.id = id
        self.userId = userId
        self.name = name
        self.balance = balance
        self.groupId = groupId
        self.currency = currency
    }
}
