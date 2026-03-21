//
//  FamilyBudgetView.swift
//  BalancePlaning
//

import SwiftUI
import SwiftData

// MARK: - Семейный бюджет

struct FamilyBudgetView: View {
    @Environment(\.modelContext) private var context
    @ObservedObject private var budgetManager = SharedBudgetManager.shared
    @ObservedObject private var autoSync      = CloudKitAutoSyncManager.shared

    @State private var joinURLText    = ""
    @State private var isLoading      = false
    @State private var errorMessage:  String?
    @State private var showShareSheet  = false
    @State private var showLeaveAlert  = false
    @State private var showStopAlert   = false
    @State private var showJoinWarning = false   // предупреждение перед подключением
    @State private var pendingJoinURL: URL?       // URL, ожидающий подтверждения

    // Отдельный контекст для синхронизации — чтобы не трогать mainContext во время
    // delete-all + insert-all, иначе @Query-вьюхи крашатся на zombie-объектах.
    private var syncService: CloudKitSyncService {
        let syncContext = ModelContext(context.container)
        syncContext.autosaveEnabled = false
        return CloudKitSyncService(context: syncContext)
    }

    var body: some View {
        VStack(spacing: 0) {
            if budgetManager.isParticipant {
                participantView
            } else if budgetManager.shareURL != nil {
                ownerView
            } else {
                setupView
            }

            // Статус последней авто-синхронизации
            if autoSync.isSyncing {
                syncStatusRow(text: "Синхронизация...", isProgress: true)
            } else if let err = autoSync.lastSyncError {
                syncStatusRow(text: "Ошибка синхр.: \(err)", isError: true)
            } else if let date = autoSync.lastSyncDate {
                syncStatusRow(text: "Синхр.: \(date.formatted(.relative(presentation: .named)))")
            }
        }
        // Предупреждение о скрытии данных при подключении
        .confirmationDialog(
            "Ваши данные останутся на устройстве",
            isPresented: $showJoinWarning,
            titleVisibility: .visible
        ) {
            Button("Подключиться", role: .destructive) {
                if let url = pendingJoinURL { performJoin(url: url) }
                pendingJoinURL = nil
            }
            Button("Отмена", role: .cancel) {
                pendingJoinURL = nil
            }
        } message: {
            Text("Пока вы подключены к общему бюджету, ваши личные записи будут скрыты (не удалены). Они вернутся, как только вы выйдете из общего бюджета.")
        }
        // Принять приглашение из URL (когда приложение открыто через ссылку)
        .onReceive(NotificationCenter.default.publisher(for: .cloudKitShareInvitationReceived)) { note in
            guard !budgetManager.isParticipant,
                  let url = note.userInfo?["url"] as? URL else { return }
            joinURLText = url.absoluteString
            initiateJoin(urlString: url.absoluteString)
        }
        // Ошибка
        .alert("Ошибка", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Варианты UI

    /// Начальный экран: создать или подключиться
    private var setupView: some View {
        VStack(spacing: 0) {
            if isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Настройка...")
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
            } else {
                Button { createSharedBudget() } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "person.2.circle.fill")
                            .foregroundStyle(AppTheme.Colors.accent)
                            .frame(width: 36, height: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Создать общий бюджет")
                                .font(.subheadline.bold())
                            Text("Пригласите партнёра по ссылке")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, 64)

                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        Image(systemName: "link.circle.fill")
                            .foregroundStyle(AppTheme.Colors.transfer)
                            .frame(width: 36, height: 36)
                        TextField("Вставить ссылку приглашения", text: $joinURLText)
                            .font(.subheadline)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    .padding(.horizontal, 16).padding(.top, 12)

                    if !joinURLText.isEmpty {
                        Button { initiateJoin(urlString: joinURLText) } label: {
                            Text("Подключиться")
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.Colors.transfer)
                        .padding(.horizontal, 16)
                    }
                    Spacer().frame(height: 12)
                }
            }
        }
        .cardStyle()
        .padding(.horizontal)
    }

    /// Вид для владельца (создал общий бюджет)
    private var ownerView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppTheme.Colors.income)
                    .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Общий бюджет активен")
                        .font(.subheadline.bold())
                    Text("Поделитесь ссылкой с партнёром")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 12)

            Divider().padding(.leading, 64)

            // Ссылка
            if let url = budgetManager.shareURL {
                HStack(spacing: 8) {
                    Text(url.absoluteString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        UIPasteboard.general.string = url.absoluteString
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .foregroundStyle(AppTheme.Colors.accent)
                    }

                    Button { showShareSheet = true } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(AppTheme.Colors.accent)
                    }
                    .sheet(isPresented: $showShareSheet) {
                        ShareSheet(items: [url])
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 10)

                Divider().padding(.leading, 16)
            }

            // Кнопки
            if isLoading || autoSync.isSyncing {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Синхронизация...")
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            } else {
                Button { syncOwner() } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.triangle.2.circlepath.icloud")
                            .foregroundStyle(AppTheme.Colors.accent)
                            .frame(width: 36)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Синхронизировать")
                                .font(.subheadline)
                            Text("Отправить и получить изменения")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, 64)

                Button(role: .destructive) { showStopAlert = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "xmark.circle")
                            .foregroundStyle(.red)
                            .frame(width: 36)
                        Text("Прекратить общий доступ")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
        }
        .cardStyle()
        .padding(.horizontal)
        .confirmationDialog(
            "Прекратить общий доступ?",
            isPresented: $showStopAlert,
            titleVisibility: .visible
        ) {
            Button("Прекратить", role: .destructive) { stopSharing() }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Партнёр потеряет доступ к бюджету")
        }
    }

    /// Вид для участника (подключён к чужому бюджету)
    private var participantView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "person.2.fill")
                    .foregroundStyle(AppTheme.Colors.accent)
                    .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Совместный бюджет")
                        .font(.subheadline.bold())
                    Text(budgetManager.ownerDisplayName.isEmpty
                         ? "Вы подключены к общему бюджету"
                         : "Бюджет: \(budgetManager.ownerDisplayName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 12)

            Divider().padding(.leading, 64)

            if isLoading || autoSync.isSyncing {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Синхронизация...")
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            } else {
                Button { syncParticipant() } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.triangle.2.circlepath.icloud")
                            .foregroundStyle(AppTheme.Colors.accent)
                            .frame(width: 36)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Синхронизировать")
                                .font(.subheadline)
                            Text("Обновить данные с партнёром")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, 64)

                Button(role: .destructive) { showLeaveAlert = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.uturn.left.circle")
                            .foregroundStyle(.red)
                            .frame(width: 36)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Выйти из общего бюджета")
                                .font(.subheadline)
                                .foregroundStyle(.red)
                            Text("Ваши личные данные снова станут видны")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
        }
        .cardStyle()
        .padding(.horizontal)
        .confirmationDialog(
            "Выйти из общего бюджета?",
            isPresented: $showLeaveAlert,
            titleVisibility: .visible
        ) {
            Button("Выйти", role: .destructive) { leaveBudget() }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Данные общего бюджета удалятся с устройства. Ваши личные записи снова станут видны.")
        }
    }

    // MARK: - Status row

    private func syncStatusRow(text: String, isProgress: Bool = false, isError: Bool = false) -> some View {
        HStack(spacing: 6) {
            if isProgress {
                ProgressView().scaleEffect(0.7)
            } else {
                Image(systemName: isError ? "exclamationmark.icloud" : "checkmark.icloud")
                    .foregroundStyle(isError ? .red : .secondary)
                    .font(.caption2)
            }
            Text(text)
                .font(.caption2)
                .foregroundStyle(isError ? .red : .secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Actions

    private func createSharedBudget() {
        isLoading = true
        Task {
            do {
                let url = try await syncService.setupAndShare()
                budgetManager.saveShareURL(url)
                // Регистрируем подписки после создания шары
                CloudKitAutoSyncManager.shared.configure(with: context.container)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    /// Проверяет наличие своих данных и показывает предупреждение или сразу подключает
    private func initiateJoin(urlString: String) {
        let trimmed = urlString.trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: trimmed) else {
            errorMessage = "Неверная ссылка"
            return
        }
        if hasOwnData() {
            pendingJoinURL = url
            showJoinWarning = true
        } else {
            performJoin(url: url)
        }
    }

    private func performJoin(url: URL) {
        isLoading = true
        Task {
            do {
                let (ownerId, ownerName) = try await syncService.acceptShareAndSeed(url: url)
                budgetManager.joinBudget(ownerId: ownerId, ownerName: ownerName)
                joinURLText = ""
                // Регистрируем подписки для участника
                CloudKitAutoSyncManager.shared.configure(with: context.container)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func syncOwner() {
        isLoading = true
        Task {
            do {
                try await syncService.ownerFullSync()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func syncParticipant() {
        isLoading = true
        Task {
            do {
                try await syncService.participantFullSync()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func stopSharing() {
        isLoading = true
        Task {
            do {
                try await syncService.stopSharing()
                budgetManager.clearShareURL()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func leaveBudget() {
        guard let ownerId = budgetManager.activeBudgetOwnerId else { return }
        syncService.deleteOwnerData(for: ownerId)
        budgetManager.leaveBudget()
    }

    /// Проверяет, есть ли у пользователя собственные данные (до подключения к чужому бюджету)
    private func hasOwnData() -> Bool {
        guard let uidStr = UserDefaults.standard.string(forKey: UserDefaultKeys.currentUserId),
              let uid = UUID(uuidString: uidStr) else { return false }
        let accounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        return accounts.contains { $0.userId == uid }
    }
}

// MARK: - ShareSheet wrapper

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}
