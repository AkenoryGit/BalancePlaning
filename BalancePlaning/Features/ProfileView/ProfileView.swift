//
//  ProfileView.swift
//  BalancePlaning
//
//  Created by Дмитрий Дудник on 09.02.2026.
//

import SwiftUI
import SwiftData

struct ProfileView: View {
    // подключаемся к SwiftData через context
    @Environment(\.modelContext) private var context
    @Binding var isLogged: Bool
    
    private var headView: Header
    
    // создаем экземпляр UserService для определения id текущего пользователя в дальнейшем
    var userService: UserService {
        UserService(context: context) }
    
    // инициализируем нужные параметры для хедера
    init(headView: Header, isLogged: Binding<Bool>) {
        self.headView = headView
        self._isLogged = isLogged
        self.headView.avatarSystemName = "person.fill"
        self.headView.trailingAvatar = 0
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                headView
                    .frame(width: geometry.size.width, height: 250)
                VStack {
                    // если все правильно с авторизацией пользотваеля, то отображаем его логин(почту) на экране
                    if let user = userService.getCurrentUser() {
                        Text(user.login)
                            .font(.title2)
                    } else {
                        Text("Пользователь не найден")
                            .foregroundStyle(.secondary)
                            .italic()
                    }
                }
                // кнопка выхода из профиля пользователя и сброс id пользователя из UserDefaults
                Button("Выйти") {
                    UserDefaults.standard.removeObject(forKey: UserDefaultKeys.currentUserId)
                    isLogged = false
                }
            }
        }
    }
}
