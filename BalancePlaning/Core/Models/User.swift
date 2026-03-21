//
//  User.swift
//  BalancePlaning
//
//  Created by Дмитрий Дудник on 04.02.2026.
//

import Foundation
import SwiftData

// модель пользователя
@Model
final class User {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var login: String
    var displayName: String = ""
    var securityQuestion: String = ""

    init(login: String, id: UUID = UUID()) {
        self.login = login
        self.id = id
    }
}
