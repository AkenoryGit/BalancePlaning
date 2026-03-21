//
//  AppDelegate.swift
//  BalancePlaning
//
//  Обрабатывает silent push-уведомления от CloudKit (content-available: 1).
//  Подключается к SwiftUI через @UIApplicationDelegateAdaptor в BalancePlaningApp.
//

import UIKit
import CloudKit

class AppDelegate: NSObject, UIApplicationDelegate {

    // MARK: - Remote notifications

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        return true
    }

    /// Вызывается из CloudKitAutoSyncManager.configure() — только когда sharing реально используется
    static func registerForPush() {
        UIApplication.shared.registerForRemoteNotifications()
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // CloudKit использует APNs токен автоматически — ничего делать не нужно
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // APNS registration failed — silent push won't work but sharing still functions manually
    }

    // MARK: - Background / silent push (content-available: 1)

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // Проверяем, что это уведомление от нашего CloudKit-контейнера
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo),
              notification.subscriptionID == "owner-budget-changes" ||
              notification.subscriptionID == "participant-budget-changes"
        else {
            completionHandler(.noData)
            return
        }

        // Запускаем синхронизацию на MainActor
        Task { @MainActor in
            CloudKitAutoSyncManager.shared.syncNow()
            completionHandler(.newData)
        }
    }
}
