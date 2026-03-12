//
//  ContentView.swift
//  BalancePlaning
//
//  Created by Дмитрий Дудник on 04.02.2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @State private var isRegistration: Bool = false
    @State private var isLoggedIn: Bool = false

    var userService: UserService {
        UserService(context: context)
    }

    var body: some View {
        TabView {
            if !isRegistration && !isLoggedIn {
                AutorizationView(isRegistration: $isRegistration, isLogged: $isLoggedIn)
                    .tabItem {
                        Label("Вход", systemImage: "person.crop.square")
                    }
            } else if !isLoggedIn && isRegistration {
                RegistrationView(isRegistration: $isRegistration, isLogin: $isLoggedIn)
                    .tabItem {
                        Label("Регистрация", systemImage: "person.crop.square")
                    }
            } else {
                TransactionsView()
                    .tabItem {
                        Label("Главная", systemImage: "house.fill")
                    }

                AnalyticsView()
                    .tabItem {
                        Label("Аналитика", systemImage: "chart.bar.fill")
                    }

                ProfileView(isLogged: $isLoggedIn)
                    .tabItem {
                        Label("Профиль", systemImage: "person.fill")
                    }
            }
        }
        .onAppear {
            isLoggedIn = userService.getCurrentUser() != nil
        }
        .onChange(of: context) {
            isLoggedIn = userService.getCurrentUser() != nil
        }
    }
}
