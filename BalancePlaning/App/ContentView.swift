//
//  ContentView.swift
//  BalancePlaning
//
//  Created by Дмитрий Дудник on 04.02.2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    // Отслеживаем какое вью выбрать, с регистрацией или авторизацией
    @State private var isRegistration: Bool = false
    // смотрим, пользователь авторизовался или нет
    @State private var isLoggedIn: Bool = false
    
    var body: some View {
        TabView {
            // если не на окне регистрации и не залогинен, то показываем окно авторизации
            if !isRegistration && !isLoggedIn {
                AutorizationView(isRegistration: $isRegistration, isLogged: $isLoggedIn)
                    .tabItem {
                        Label("Авторизация", systemImage: "person.crop.square")
                    }
                //если еще не залогинен и выбрана регистрация, то показываем окно регистрации
            } else if !isLoggedIn && isRegistration {
                RegistrationView(isRegistration: $isRegistration, isLogin: $isLoggedIn)
                    .tabItem {
                        Label("Регистрация", systemImage: "person.crop.square")
                    }
                // в остальных случаях показываем окно профиля
            } else {
                ProfileView(headView: Header(title: "Профиль"), isLogged: $isLoggedIn)
                    .tabItem {
                        Label("Профиль", systemImage: "person.crop.square")
                    }
            }
        }
    }
}

#Preview {
    ContentView()
}
