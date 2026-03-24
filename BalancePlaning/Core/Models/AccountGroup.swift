//
//  AccountGroup.swift
//  BalancePlaning
//

import Foundation
import SwiftData

@Model
class AccountGroup {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var name: String
    var color: String = ""

    init(id: UUID = UUID(), userId: UUID, name: String, color: String = "") {
        self.id = id
        self.userId = userId
        self.name = name
        self.color = color
    }
}
