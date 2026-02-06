//
//  BalancePlaningApp.swift
//  BalancePlaning
//
//  Created by Дмитрий Дудник on 04.02.2026.
//

import SwiftUI
import SwiftData

@main
struct BalancePlaningApp: App {

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [User.self])
    }
}
