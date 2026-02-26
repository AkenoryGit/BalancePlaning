//
//  HeadSectionViewModel.swift
//  BalancePlaning
//
//  Created by Дмитрий Дудник on 05.02.2026.
//

import SwiftUI

// Модель хедера для некоторых окон
struct Header: View {
    // задаем титул для хедера
    var title: String
    // выбираем картинку для аватарки
    var avatarSystemName: String = "person.crop.circle.badge.questionmark"
    // выбираем смешение от правой стороны экрана для аватарки
    var trailingAvatar: CGFloat = 10
    
    var body: some View {
        // ставим GeometryReader для вычисления расстояний на этой View
        GeometryReader { geometry in
            // узнаем ширину экрана
            let width: CGFloat = geometry.size.width
            // накладываем поверх друг друга несколько элементов
            ZStack(alignment: .top) {
                // в самом низу картинка с облоками
                Image("cloudBackground")
                    .resizable()
                    .frame(width: width, height: 200)
                    .padding(.top, 50)
                // рисуем белую шапку сверху картинки
                Path { path in
                    path.move(to: .zero)
                    path.addLine(to: CGPoint(x: 0, y: 50))
                    path.addQuadCurve(to: CGPoint(x: width, y: 50), control: CGPoint(x: width/2, y: 50 * 2))
                    path.addLine(to: CGPoint (x: width, y: 0))
                    path.closeSubpath()
                }
                .fill(Color.white)
                // рисуем изогнутую линию между белой шапкой и картинкой с облоками
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 50))
                    path.addQuadCurve(to: CGPoint(x: width, y: 50), control: CGPoint(x: width/2, y: 50 * 2))
                }
                .stroke(Color.gray, style: StrokeStyle(lineWidth: 1))
                .shadow(color: Color.black, radius: 3, x: 0, y: 3)
                // рисуем тень под картинкой
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 250))
                    path.addLine(to: CGPoint(x: width, y: 250))
                    path.closeSubpath()
                }
                .stroke(Color.gray.opacity(0.1), style: StrokeStyle(lineWidth: 1))
                .shadow(color: Color.black.opacity(0.8), radius: 3, x: 0, y: 3)
                // ставим аватарку в центр
                Image(systemName: avatarSystemName)
                    .resizable()
                    .frame(width: 100, height: 100)
                    .foregroundStyle(Color.black.opacity(0.3))
                    .padding(.top, 105)
                    .padding(.trailing, trailingAvatar)
                // поверх всего пишем титул хедера
                Text(title)
                    .padding(.top, 10)
                    .font(.title)
                    .bold()
            }
        }
    }
}

//#Preview {
//    Header(title: "Авторизация")
//}
