//
//  HeadSectionView.swift
//  BalancePlaning
//
//  Created by Дмитрий Дудник on 05.02.2026.
//

import SwiftUI

struct HeadSectionView: View {
    let height: CGFloat = 50
    var title: String
    
    var body: some View {
        GeometryReader { geometry in
            let width: CGFloat = geometry.size.width
            ZStack(alignment: .top) {
                Image("cloudBackground")
                    .resizable()
                    .frame(width: width, height: 200)
                    .padding(.top, 50)
                Path { path in
                    path.move(to: .zero)
                    path.addLine(to: CGPoint(x: 0, y: height))
                    path.addQuadCurve(to: CGPoint(x: width, y: height), control: CGPoint(x: width/2, y: height * 2))
                    path.addLine(to: CGPoint (x: width, y: 0))
                    path.closeSubpath()
                }
                .fill(Color.white)
                .mask(Image("cloudBackground"))
                Path { path in
                    path.move(to: CGPoint(x: 0, y: height))
                    path.addQuadCurve(to: CGPoint(x: width, y: height), control: CGPoint(x: width/2, y: height * 2))
                }
                .stroke(Color.gray, style: StrokeStyle(lineWidth: 1))
                .shadow(color: Color.black, radius: 3, x: 0, y: 3)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 250))
                    path.addLine(to: CGPoint(x: width, y: 250))
                    path.closeSubpath()
                }
                .stroke(Color.gray.opacity(0.1), style: StrokeStyle(lineWidth: 1))
                .shadow(color: Color.black.opacity(0.8), radius: 3, x: 0, y: 3)
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .resizable()
                    .frame(width: 140, height: 120)
                    .foregroundStyle(Color.black.opacity(0.3))
                    .padding(.top, 105)
                    .padding(.trailing, 10)
                Text(title)
                    .padding(.top, 10)
                    .font(.title)
                    .bold()
            }
        }
    }
}

#Preview {
    HeadSectionView(title: "Авторизация")
}
