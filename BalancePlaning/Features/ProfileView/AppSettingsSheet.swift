//
//  AppSettingsSheet.swift
//  BalancePlaning
//

import SwiftUI
import UIKit
import UserNotifications

struct AppSettingsSheet: View {
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showPermissionDeniedAlert = false

    var body: some View {
        NavigationStack {
            List {
                // MARK: Оформление
                Section("Оформление / Appearance") {
                    ForEach(AppSettings.ThemeOption.allCases, id: \.self) { option in
                        Button {
                            settings.theme = option
                        } label: {
                            HStack {
                                Label(option.label, systemImage: themeIcon(option))
                                    .foregroundStyle(.primary)
                                Spacer()
                                if settings.theme == option {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(AppTheme.Colors.accent)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                }

                // MARK: Язык
                Section("Язык / Language") {
                    ForEach(AppSettings.Language.allCases, id: \.self) { option in
                        Button {
                            settings.language = option
                        } label: {
                            HStack {
                                Label(option.label, systemImage: languageIcon(option))
                                    .foregroundStyle(.primary)
                                Spacer()
                                if settings.language == option {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(AppTheme.Colors.accent)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                }

                // MARK: Уведомления
                Section {
                    Toggle(isOn: Binding(
                        get: { settings.notificationsEnabled },
                        set: { enabled in
                            if enabled {
                                NotificationService.requestPermission { granted in
                                    if granted {
                                        settings.notificationsEnabled = true
                                    } else {
                                        showPermissionDeniedAlert = true
                                    }
                                }
                            } else {
                                settings.notificationsEnabled = false
                            }
                        }
                    )) {
                        Label("Ежедневное напоминание", systemImage: "bell.fill")
                    }
                    .tint(AppTheme.Colors.accent)

                    if settings.notificationsEnabled {
                        DatePicker(
                            "Время напоминания",
                            selection: $settings.notificationTime,
                            displayedComponents: [.hourAndMinute]
                        )
                    }
                } header: {
                    Text("Уведомления / Notifications")
                } footer: {
                    if settings.notificationsEnabled {
                        Text("Каждый день в выбранное время придёт напоминание внести траты")
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Настройки / Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово / Done") { dismiss() }
                }
            }
            .alert("Уведомления отключены", isPresented: $showPermissionDeniedAlert) {
                Button("Открыть настройки") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Разрешите уведомления в настройках iPhone, чтобы получать напоминания.")
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func themeIcon(_ option: AppSettings.ThemeOption) -> String {
        switch option {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max"
        case .dark:   return "moon"
        }
    }

    private func languageIcon(_ option: AppSettings.Language) -> String {
        switch option {
        case .system:  return "gearshape"
        case .russian: return "globe"
        case .english: return "globe"
        }
    }
}
