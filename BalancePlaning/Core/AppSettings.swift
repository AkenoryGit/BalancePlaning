//
//  AppSettings.swift
//  BalancePlaning
//

import SwiftUI
import Combine

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // MARK: - Theme

    enum ThemeOption: String, CaseIterable {
        case system = "system"
        case light  = "light"
        case dark   = "dark"

        var label: String {
            let bundle = AppSettings.shared.bundle
            switch self {
            case .system: return bundle.localizedString(forKey: "Системная", value: "Системная", table: nil)
            case .light:  return bundle.localizedString(forKey: "Светлая",   value: "Светлая",   table: nil)
            case .dark:   return bundle.localizedString(forKey: "Тёмная",    value: "Тёмная",    table: nil)
            }
        }

        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light:  return .light
            case .dark:   return .dark
            }
        }
    }

    @Published var theme: ThemeOption {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: "appTheme") }
    }

    // MARK: - Language

    enum Language: String, CaseIterable {
        case system  = "system"
        case russian = "ru"
        case english = "en"

        var label: String {
            switch self {
            case .system:  return "System / Системный"
            case .russian: return "Русский"
            case .english: return "English"
            }
        }

        var locale: Locale {
            switch self {
            case .system:  return Locale.current
            case .russian: return Locale(identifier: "ru_RU")
            case .english: return Locale(identifier: "en_US")
            }
        }

        /// Bundle для локализации строк
        var bundle: Bundle {
            switch self {
            case .system:
                // Определяем язык системы: если это русский — нет lproj (используем ключи),
                // иначе пробуем найти en.lproj
                let langCode = Locale.current.language.languageCode?.identifier ?? "ru"
                if langCode == "en", let path = Bundle.main.path(forResource: "en", ofType: "lproj"),
                   let b = Bundle(path: path) { return b }
                return .main
            case .russian:
                return .main
            case .english:
                if let path = Bundle.main.path(forResource: "en", ofType: "lproj"),
                   let b = Bundle(path: path) { return b }
                return .main
            }
        }
    }

    @Published var language: Language {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "appLanguage")
            // Перепланируем уведомление с новым языком
            NotificationService.rescheduleIfNeeded()
        }
    }

    // MARK: - Notifications

    @Published var notificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled")
            if notificationsEnabled {
                NotificationService.scheduleReminder(at: notificationTime)
            } else {
                NotificationService.cancelReminder()
            }
        }
    }

    @Published var notificationTime: Date {
        didSet {
            UserDefaults.standard.set(notificationTime.timeIntervalSince1970, forKey: "notificationTime")
            if notificationsEnabled {
                NotificationService.scheduleReminder(at: notificationTime)
            }
        }
    }

    var locale: Locale { language.locale }
    var bundle: Bundle { language.bundle }

    private init() {
        let rawTheme = UserDefaults.standard.string(forKey: "appTheme") ?? ""
        theme = ThemeOption(rawValue: rawTheme) ?? .system

        let rawLang = UserDefaults.standard.string(forKey: "appLanguage") ?? ""
        language = Language(rawValue: rawLang) ?? .system

        notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")

        let savedInterval = UserDefaults.standard.double(forKey: "notificationTime")
        if savedInterval > 0 {
            notificationTime = Date(timeIntervalSince1970: savedInterval)
        } else {
            // По умолчанию: 21:00
            var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            comps.hour = 21; comps.minute = 0
            notificationTime = Calendar.current.date(from: comps) ?? Date()
        }
    }
}
