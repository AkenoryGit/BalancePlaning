//
//  AutorizationView.swift
//  BalancePlaning
//
//  Created by Дмитрий Дудник on 05.02.2026.
//

import SwiftUI
import SwiftData

struct AutorizationView: View {
    @Binding var isRegistrztion: Bool
    @Query(sort: \User.login) var users:[User] = []
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 20) {
                HeadSectionView(title: "Авторизация")
                    .frame(width: geometry.size.width, height: 250)
                VStack(spacing: 0) {
                    TextField("Логин", text: .constant(""))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: geometry.size.width - 40, height: 50)
                    TextField("Пароль", text: .constant(""))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: geometry.size.width - 40, height: 50)
                }
                Button {
                    
                } label: {
                    Text("Войти")
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .font(Font.system(size: 18, weight: .bold, design: .default))
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.green))
                        .foregroundColor(.white)
                }
                Button {
                    isRegistrztion = true
                } label: {
                    Text("Зарегистрироваться")
                        .foregroundStyle(Color.blue)
                }
            }
        }
    }
}

