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
    
    init(id: UUID, userId: UUID, name: String, balance: Decimal) {
        self.id = id
        self.userId = userId
        self.name = name
        self.balance = balance
    }
}
