//
//  CurrentUserId.swift
//  BalancePlaning
//

import Foundation

/// Возвращает UUID для фильтрации данных:
/// — если пользователь подключён к чужому бюджету → UUID владельца
/// — иначе → UUID текущего пользователя
func currentUserId() -> UUID? {
    // Режим общего бюджета: используем userId владельца
    if let sharedOwnerId = SharedBudgetManager.shared.activeBudgetOwnerId {
        return sharedOwnerId
    }
    guard let uuidString = UserDefaults.standard.string(forKey: UserDefaultKeys.currentUserId) else {
        return nil
    }
    return UUID(uuidString: uuidString)
}
