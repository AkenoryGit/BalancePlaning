//
//  TopHead.swift
//  BalancePlaning
//
//  Created by Дмитрий Дудник on 26.02.2026.
//

import SwiftUI

struct TopHead: View {
    var title: String
    
    var body: some View {
        // ставим GeometryReader для вычисления расстояний на этой View
        GeometryReader { geometry in
            // узнаем ширину экрана
            let width: CGFloat = geometry.size.width
            // накладываем поверх друг друга несколько элементов
                ZStack(alignment: .top) {
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
                    // поверх всего пишем титул хедера
                    Text(title)
                        .padding(.top, 10)
                        .font(.title)
                        .bold()
                }
        }
    }
}
