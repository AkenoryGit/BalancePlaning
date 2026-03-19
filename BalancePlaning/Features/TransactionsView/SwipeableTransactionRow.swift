//
//  SwipeableTransactionRow.swift
//  BalancePlaning
//

import SwiftUI

/// Строка транзакции с кастомным свайпом:
/// - Вправо→влево: частичный свайп → кнопка корзины; полный свайп → сразу вызывает onDelete
/// - Влево→вправо: вызывает onToggleSelect
struct SwipeableTransactionRow: View {
    let transaction: Transaction
    let allCategories: [Category]
    let allGroups: [AccountGroup]
    let showDate: Bool
    let isSelected: Bool

    var onTap: () -> Void
    var onDelete: () -> Void
    var onToggleSelect: () -> Void

    @State private var offset: CGFloat = 0
    @State private var isHorizontalGesture: Bool? = nil

    private let actionWidth: CGFloat = 80
    private let fullSwipeThreshold: CGFloat = 150
    private let selectThreshold: CGFloat = 40

    var body: some View {
        ZStack(alignment: .trailing) {
            // Красная зона удаления (за карточкой, справа)
            deleteZone

            // Карточка транзакции
            TransactionCard(
                transaction: transaction,
                allCategories: allCategories,
                allGroups: allGroups,
                showDate: showDate
            )
            .overlay(alignment: .topLeading) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.accent)
                        .background(Circle().fill(.white).padding(-3))
                        .padding(.leading, 10)
                        .padding(.top, 10)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .offset(x: offset)
            .contentShape(Rectangle())
            .onTapGesture {
                if offset != 0 {
                    withAnimation(.spring(duration: 0.3)) { offset = 0 }
                } else {
                    onTap()
                }
            }
        }
        .padding(.horizontal)
        .simultaneousGesture(dragGesture)
    }

    // MARK: - Delete zone

    @ViewBuilder
    private var deleteZone: some View {
        let w = max(0, -offset)
        if w > 0 {
            Color.red
                .frame(width: w)
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: AppTheme.cardRadius,
                    topTrailingRadius: AppTheme.cardRadius
                ))
                .overlay {
                    if w > 20 {
                        Image(systemName: "trash.fill")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                    }
                }
                .onTapGesture { onDelete() }
        }
    }

    // MARK: - Gesture

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onChanged { value in
                let dx = value.translation.width
                let dy = value.translation.height

                // Определяем направление жеста только один раз
                if isHorizontalGesture == nil, abs(dx) > 10 || abs(dy) > 10 {
                    isHorizontalGesture = abs(dx) > abs(dy)
                }
                guard isHorizontalGesture == true else { return }

                if dx < 0 {
                    // Вправо→влево: сдвигаем карточку с небольшим сопротивлением за порогом
                    let limit = fullSwipeThreshold + 30
                    offset = dx > -limit ? dx : -limit - (dx + limit) * 0.2
                } else {
                    if offset < 0 {
                        // Закрываем открытую зону
                        offset = min(0, offset + dx)
                    } else {
                        // Влево→вправо: пружинящий отклик
                        offset = min(30, dx * 0.3)
                    }
                }
            }
            .onEnded { value in
                defer { isHorizontalGesture = nil }

                guard isHorizontalGesture == true else {
                    if offset != 0 {
                        withAnimation(.spring(duration: 0.3)) { offset = 0 }
                    }
                    return
                }

                let dx = value.translation.width
                let vx = value.velocity.width

                if dx < -fullSwipeThreshold || vx < -900 {
                    // Полный свайп: удаление
                    withAnimation(.spring(duration: 0.25)) { offset = 0 }
                    onDelete()
                } else if dx < -(actionWidth * 0.45) {
                    // Частичный: показываем кнопку
                    withAnimation(.spring(duration: 0.3)) { offset = -actionWidth }
                } else if dx > selectThreshold || (dx > 10 && vx > 500) {
                    // Влево→вправо: выделение
                    withAnimation(.spring(duration: 0.2)) { offset = 0 }
                    onToggleSelect()
                } else {
                    withAnimation(.spring(duration: 0.3)) { offset = 0 }
                }
            }
    }
}
