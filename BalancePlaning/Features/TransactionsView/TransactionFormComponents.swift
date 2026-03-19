//
//  TransactionFormComponents.swift
//  BalancePlaning
//

import SwiftUI
import SwiftData

// MARK: - Поле ввода суммы

struct AmountInputCard: View {
    let icon: String
    let typeLabel: LocalizedStringKey
    let color: Color
    @Binding var amount: String
    var showError: Bool = false

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(color)

            Text(typeLabel)
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("", text: $amount)
                .font(.system(size: 52, weight: .bold))
                .multilineTextAlignment(.center)
                .keyboardType(.decimalPad)
                .foregroundStyle(showError ? .red : .primary)
                .minimumScaleFactor(0.5)
                .overlay(alignment: .center) {
                    if amount.isEmpty {
                        Text("0")
                            .font(.system(size: 52, weight: .bold))
                            .foregroundStyle(.quaternary)
                            .allowsHitTesting(false)
                    }
                }
                .padding(.vertical, 4)

            if showError {
                Text("Введите сумму больше нуля")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .cardStyle()
        .animation(.easeInOut(duration: 0.2), value: showError)
    }
}

// MARK: - Секция расписания

struct ScheduleSection: View {
    @Binding var date: Date
    @Binding var endDate: Date
    @Binding var isRecurring: Bool
    @Binding var interval: RecurringInterval?
    @Binding var intervalDays: String

    @FocusState private var daysFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Toggle(isOn: $isRecurring.animation()) {
                HStack(spacing: 10) {
                    Image(systemName: isRecurring ? "repeat.circle.fill" : "calendar.circle.fill")
                        .foregroundStyle(AppTheme.Colors.accent)
                        .frame(width: 20)
                    Text(LocalizedStringKey(isRecurring ? "Повторяется" : "Один раз"))
                        .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider().padding(.leading, 16)

            if isRecurring {
                HStack {
                    Text("Интервал")
                    Spacer()
                    Picker("", selection: $interval) {
                        ForEach(RecurringInterval.allCases, id: \.self) { i in
                            Text(LocalizedStringKey(i.displayName)).tag(Optional(i))
                        }
                    }
                    .labelsHidden()
                    .tint(AppTheme.Colors.accent)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                if interval == .everyNDays {
                    Divider().padding(.leading, 16)
                    HStack {
                        Text("Количество дней")
                        Spacer()
                        TextField("2", text: $intervalDays)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                            .focused($daysFieldFocused)
                            .onChange(of: daysFieldFocused) { _, focused in
                                if focused {
                                    intervalDays = ""
                                } else {
                                    let val = Int(intervalDays) ?? 0
                                    intervalDays = val > 0 ? String(val) : "2"
                                }
                            }
                            .onChange(of: intervalDays) { _, new in
                                let digits = new.filter { $0.isNumber }
                                if digits != new { intervalDays = digits }
                            }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }

                Divider().padding(.leading, 16)
                scheduleDateRow(label: "Начало", date: $date)

                Divider().padding(.leading, 16)
                HStack {
                    Text("Конец")
                    Spacer()
                    DatePicker(
                        "",
                        selection: $endDate,
                        in: date...Calendar.current.date(byAdding: .year, value: 1, to: date)!,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            } else {
                scheduleDateRow(label: "Дата", date: $date)
            }
        }
        .cardStyle()
        .animation(.easeInOut(duration: 0.2), value: isRecurring)
        .animation(.easeInOut(duration: 0.15), value: interval == .everyNDays)
    }

    private func scheduleDateRow(label: LocalizedStringKey, date: Binding<Date>) -> some View {
        HStack {
            Text(label)
            Spacer()
            DatePicker("", selection: date, displayedComponents: [.date])
                .datePickerStyle(.compact)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Секция важности

struct PrioritySection: View {
    @Binding var priority: TransactionPriority

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Важность")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("· влияет на порядок в списке за день")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)

            HStack(spacing: 8) {
                ForEach(TransactionPriority.allCases, id: \.self) { p in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { priority = p }
                    } label: {
                        Text(LocalizedStringKey(p.displayName))
                            .font(.subheadline)
                            .fontWeight(priority == p ? .semibold : .regular)
                            .foregroundStyle(priority == p ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(priority == p ? p.activeColor : Color(.tertiarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .animation(.easeInOut(duration: 0.15), value: priority)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .cardStyle()
    }
}

// MARK: - Нижняя кнопка сохранения

struct TransactionSaveBar: View {
    let label: LocalizedStringKey
    let color: Color
    let action: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            Button(action: action) {
                Text(label)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [color, color.opacity(0.75)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonRadius))
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(.secondarySystemGroupedBackground))
    }
}

// MARK: - Строка пикера (Menu)

func pickerRow<MenuContent: View>(
    icon: String,
    iconColor: Color,
    label: LocalizedStringKey,
    value: String?,
    hasError: Bool,
    errorText: LocalizedStringKey,
    @ViewBuilder menuContent: () -> MenuContent
) -> some View {
    VStack(alignment: .leading, spacing: 0) {
        Menu {
            menuContent()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                    .frame(width: 20)
                Text(label)
                    .foregroundStyle(.primary)
                Spacer()
                Group {
                    if let v = value { Text(v) } else { Text("Выбрать") }
                }
                .foregroundStyle(hasError ? .red : .secondary)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)

        if hasError {
            Text(errorText)
                .font(.caption)
                .foregroundStyle(.red)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}
