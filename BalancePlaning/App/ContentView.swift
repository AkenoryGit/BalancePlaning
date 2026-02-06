//
//  ContentView.swift
//  BalancePlaning
//
//  Created by Дмитрий Дудник on 04.02.2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var isRegistration: Bool = false
    
    var body: some View {
        TabView {
            if !isRegistration {
                AutorizationView(isRegistrztion: $isRegistration)
                    .tabItem {
                        Label("Авторизация", systemImage: "person.crop.square")
                    }
            } else {
                RegistrationView(isRegistration: $isRegistration)
                    .tabItem {
                        Label("Регистрация", systemImage: "person.crop.square")
                    }
            }
        }
    }
}


#Preview {
    ContentView()
}
