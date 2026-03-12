//
//  CurrentUserId.swift
//  BalancePlaning
//
//  Created by Дмитрий Дудник on 27.02.2026.
//

import Foundation

func currentUserId() -> UUID? {
    guard let uuidString = UserDefaults.standard.string(forKey: UserDefaultKeys.currentUserId) else {
        return nil
    }
    return UUID(uuidString: uuidString)
}
