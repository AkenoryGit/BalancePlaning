//
//  SharedBudgetManager.swift
//  BalancePlaning
//

import Foundation
import Combine

// MARK: - Менеджер общего семейного бюджета

/// Хранит состояние режима общего бюджета.
/// Если activeBudgetOwnerId != nil — текущий пользователь является участником
/// (подключён к чужому бюджету); currentUserId() возвращает этот UUID.
@MainActor
class SharedBudgetManager: ObservableObject {

    static let shared = SharedBudgetManager()

    /// UUID владельца бюджета. nil = пользователь ведёт свой бюджет.
    @Published var activeBudgetOwnerId: UUID?
    /// Имя владельца (для отображения в UI участнику)
    @Published var ownerDisplayName: String = ""
    /// URL приглашения (доступен владельцу после создания общего бюджета)
    @Published var shareURL: URL?

    var isParticipant: Bool { activeBudgetOwnerId != nil }

    private enum Keys {
        static let ownerId   = "sharedBudget_ownerId"
        static let ownerName = "sharedBudget_ownerName"
        static let shareURL  = "sharedBudget_shareURL"
    }

    private init() { restore() }

    // MARK: - Persistence

    private func restore() {
        if let s = UserDefaults.standard.string(forKey: Keys.ownerId),
           let id = UUID(uuidString: s) {
            activeBudgetOwnerId = id
        }
        ownerDisplayName = UserDefaults.standard.string(forKey: Keys.ownerName) ?? ""
        if let s = UserDefaults.standard.string(forKey: Keys.shareURL),
           let url = URL(string: s) {
            shareURL = url
        }
    }

    // MARK: - Actions

    /// Участник принимает приглашение: сохраняем ownerId + имя владельца
    func joinBudget(ownerId: UUID, ownerName: String) {
        activeBudgetOwnerId = ownerId
        ownerDisplayName = ownerName
        UserDefaults.standard.set(ownerId.uuidString, forKey: Keys.ownerId)
        UserDefaults.standard.set(ownerName, forKey: Keys.ownerName)
    }

    /// Участник выходит из общего бюджета
    func leaveBudget() {
        activeBudgetOwnerId = nil
        ownerDisplayName = ""
        UserDefaults.standard.removeObject(forKey: Keys.ownerId)
        UserDefaults.standard.removeObject(forKey: Keys.ownerName)
    }

    /// Сохраняем URL приглашения (владелец создал шару)
    func saveShareURL(_ url: URL) {
        shareURL = url
        UserDefaults.standard.set(url.absoluteString, forKey: Keys.shareURL)
    }

    /// Удаляем URL приглашения (владелец прекратил общий доступ)
    func clearShareURL() {
        shareURL = nil
        UserDefaults.standard.removeObject(forKey: Keys.shareURL)
    }
}
