//
//  MonthSelector.swift
//  BalancePlaning
//

import SwiftUI

// MARK: - Выбор месяца

struct MonthSelector: View {
    @Binding var selectedMonth: Date

    var body: some View {
        HStack {
            Button {
                selectedMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
            } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline.bold())
                    .frame(width: 36, height: 36)
                    .background(Color(.systemBackground))
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
            }

            Spacer()

            Text(selectedMonth.formatted(.dateTime
                .locale(Locale(identifier: "ru_RU"))
                .month(.wide)
                .year(.defaultDigits)
            ))
            .font(.headline)

            Spacer()

            Button {
                selectedMonth = Calendar.current.date(byAdding: .month, value: +1, to: selectedMonth) ?? selectedMonth
            } label: {
                Image(systemName: "chevron.right")
                    .font(.subheadline.bold())
                    .frame(width: 36, height: 36)
                    .background(Color(.systemBackground))
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
            }
        }
        .padding(.vertical, 4)
    }
}
