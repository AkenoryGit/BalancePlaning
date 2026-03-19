//
//  NotificationService.swift
//  BalancePlaning
//

import Foundation
import UserNotifications

struct NotificationService {

    static let reminderIdentifier = "daily_budget_reminder"

    // MARK: - Permission

    static func requestPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    static func checkPermission(completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async { completion(settings.authorizationStatus) }
        }
    }

    // MARK: - Scheduling

    static func scheduleReminder(at time: Date) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])

        let bundle = AppSettings.shared.bundle
        let content = UNMutableNotificationContent()
        content.title = bundle.localizedString(forKey: "Напоминание", value: "Напоминание", table: nil)
        content.body  = bundle.localizedString(forKey: "Пора внести траты за день", value: "Пора внести траты за день", table: nil)
        content.sound = .default

        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        let trigger    = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request    = UNNotificationRequest(identifier: reminderIdentifier, content: content, trigger: trigger)

        center.add(request)
    }

    static func cancelReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])
    }

    // MARK: - Reschedule (called on app launch and language change)

    static func rescheduleIfNeeded() {
        guard AppSettings.shared.notificationsEnabled else { return }
        scheduleReminder(at: AppSettings.shared.notificationTime)
    }
}
