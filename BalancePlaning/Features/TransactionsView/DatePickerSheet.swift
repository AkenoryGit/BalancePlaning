//
//  DatePickerSheet.swift
//  BalancePlaning
//

import SwiftUI

// MARK: - DatePicker Sheet

struct DatePickerSheet: View {
    @Binding var date: Date
    let onShowAll: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 40, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 8)

            DatePicker("", selection: $date, displayedComponents: [.date])
                .datePickerStyle(.graphical)
                .padding(.horizontal)

            Button {
                onShowAll()
                dismiss()
            } label: {
                Text("Показать все операции")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Empty State

struct EmptyTransactionsPlaceholder: View {
    let viewMode: TransactionViewMode

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: viewMode == .period ? "line.3.horizontal.decrease.circle" : "tray")
                .font(.system(size: 52))
                .foregroundStyle(.quaternary)
            Text(emptyTitle)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(emptySubtitle)
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
    }

    private var emptyTitle: LocalizedStringKey {
        switch viewMode {
        case .day:    return "Операций за этот день нет"
        case .all:    return "Операций ещё нет"
        case .period: return "Нет операций по фильтру"
        }
    }

    private var emptySubtitle: LocalizedStringKey {
        switch viewMode {
        case .day, .all: return "Нажмите + чтобы добавить первую операцию"
        case .period:    return "Попробуйте изменить период или фильтры"
        }
    }
}
