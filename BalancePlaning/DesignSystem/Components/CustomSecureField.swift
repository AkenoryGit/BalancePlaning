//
//  CustomSecureField.swift
//  BalancePlaning
//
//  Created by Дмитрий Дудник on 23.02.2026.
//

import SwiftUI

struct CustomSecureField: View {
    @State private var isSecure: Bool = true
    @Binding var password: String
    let title: String
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .trailing) {
                Group {
                    if isSecure {
                        SecureField(title, text: $password)
                    } else {
                        TextField(title, text: $password)
                    }
                }
                .textFieldStyle(.roundedBorder)
                .frame(width: geometry.size.width - 40, height: 50)
                    .padding(.leading, 20)
                Button {
                    isSecure.toggle()
                } label: {
                    Image(systemName: isSecure ? "eye.slash" : "eye")
                        .accentColor(.gray)
                }
                .padding(.trailing, 20)
            }
        }
        .frame(height: 50)
    }
}
