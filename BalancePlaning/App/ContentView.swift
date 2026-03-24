//
//  ContentView.swift
//  BalancePlaning
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @State private var isRegistration: Bool = false
    @State private var isLoggedIn: Bool = false
    @State private var selectedTab: Int = 0
    @State private var showAddSheet: Bool = false
    @State private var showAddLoan: Bool = false
    @State private var showProfileAdd: Bool = false
    @State private var selectionModel = TransactionSelectionModel()

    var userService: UserService {
        UserService(context: context)
    }

    var body: some View {
        Group {
            if !isRegistration && !isLoggedIn {
                AutorizationView(isRegistration: $isRegistration, isLogged: $isLoggedIn)
            } else if !isLoggedIn && isRegistration {
                RegistrationView(isRegistration: $isRegistration, isLogin: $isLoggedIn)
            } else {
                mainContent
            }
        }
        .onAppear {
            isLoggedIn = SharedBudgetManager.shared.isParticipant || userService.getCurrentUser() != nil
        }
        .onChange(of: context) {
            isLoggedIn = SharedBudgetManager.shared.isParticipant || userService.getCurrentUser() != nil
        }
    }

    private var mainContent: some View {
        TabView(selection: $selectedTab) {
            TransactionsView()
                .tag(0)
                .toolbar(.hidden, for: .tabBar)
            AnalyticsView()
                .tag(1)
                .toolbar(.hidden, for: .tabBar)
            LoansView(showAddLoan: $showAddLoan)
                .tag(2)
                .toolbar(.hidden, for: .tabBar)
            ProfileView(isLogged: $isLoggedIn)
                .tag(3)
                .toolbar(.hidden, for: .tabBar)
        }
        .environment(selectionModel)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                if selectionModel.isSelecting {
                    selectionBarView
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                MainTabBar(selectedTab: $selectedTab) {
                    switch selectedTab {
                    case 2: showAddLoan    = true
                    case 3: showProfileAdd = true
                    default: showAddSheet  = true
                    }
                }
            }
            .animation(.spring(duration: 0.3), value: selectionModel.isSelecting)
        }
        .sheet(isPresented: $showAddSheet) {
            TransactionsCategoryView(isRootPresented: $showAddSheet)
        }
        .sheet(isPresented: $showProfileAdd) {
            ProfileAddOptionsSheet()
        }
    }

    // MARK: - Selection Bar (above tab bar)

    private var selectionBarView: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 16) {
                Button {
                    selectionModel.onCancel()
                } label: {
                    Text("Отменить")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(selectionModel.countLabel)
                    .font(.subheadline.bold())

                Spacer()

                Button {
                    selectionModel.onBatchDelete()
                } label: {
                    Label("Удалить", systemImage: "trash")
                        .foregroundStyle(.red)
                        .font(.subheadline.bold())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .background(Color(.secondarySystemGroupedBackground))
    }
}

// MARK: - Custom Tab Bar

private struct MainTabBar: View {
    @Binding var selectedTab: Int
    let onAdd: () -> Void

    private let barHeight: CGFloat   = 56
    private let buttonSize: CGFloat  = 64   // чуть крупнее
    private let cornerRadius: CGFloat = 26
    // topSpace < buttonSize/2 → центр кнопки оказывается ниже верхней линии бара
    // buttonSize/2 = 32, topSpace = 26 → центр на 6pt ниже верха бара
    private let topSpace: CGFloat    = 26
    private let bottomSpace: CGFloat = 8

    var body: some View {
        VStack(spacing: 0) {
            // Прозрачная зона сверху — кнопка «висит» в ней
            Spacer().frame(height: topSpace)

            // Сам плавающий бар
            HStack(spacing: 0) {
                tabButton(index: 0, icon: "house.fill",       label: "Главная")
                tabButton(index: 1, icon: "chart.bar.fill",   label: "Аналитика")
                // Пустое место под центральную кнопку
                Color.clear.frame(width: 76)
                tabButton(index: 2, icon: "creditcard.fill",  label: "Кредиты")
                tabButton(index: 3, icon: "person.fill",      label: "Профиль")
            }
            .frame(height: barHeight)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.bar)
                    .shadow(color: AppTheme.Colors.accent.opacity(0.22), radius: 18, x: 0, y: 0)
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: -2)
            }
            .padding(.horizontal, 20)   // отступы слева и справа — не до края

            // Зазор снизу до home indicator
            Spacer().frame(height: bottomSpace)
        }
        // Кнопка «+» поверх всего, прижата к верхнему краю VStack
        // При topSpace=36 и buttonSize=56 центр кнопки = 28pt от верха
        // Верх бара = topSpace = 36pt от верха → кнопка на 8pt выше бара ✓
        .overlay(alignment: .top) {
            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .frame(width: buttonSize, height: buttonSize)
                    .background(
                        LinearGradient(
                            colors: [AppTheme.Colors.accent, AppTheme.Colors.accentSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())
                    .shadow(color: AppTheme.Colors.accent.opacity(0.45), radius: 12, x: 0, y: 4)
            }
        }
    }

    private func tabButton(index: Int, icon: String, label: String) -> some View {
        Button {
            selectedTab = index
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 21))
                Text(label)
                    .font(.caption2)
            }
            .foregroundStyle(selectedTab == index ? AppTheme.Colors.accent : Color(UIColor.secondaryLabel))
            .frame(maxWidth: .infinity)
            .frame(height: barHeight)
        }
        .buttonStyle(.plain)
    }
}
