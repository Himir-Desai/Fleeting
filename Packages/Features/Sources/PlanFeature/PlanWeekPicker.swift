import Core
import DesignSystem
import SwiftUI

/// Seven accessible day buttons and navigation between weeks.
struct PlanWeekPicker: View {
    @Bindable var model: PlanModel
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(spacing: Spacing.regular) {
            HStack {
                Button { model.shiftWeek(-1) } label: { Image(systemName: "chevron.left") }
                    .accessibilityLabel("Previous week")
                    .frame(minWidth: 44, minHeight: 44)
                Spacer()
                if let date = model.selectedDay.date(timeZone: model.calendar.timeZone) {
                    Text(date, format: .dateTime.month(.wide).year()).font(Typography.title)
                        .foregroundStyle(Palette.ink)
                }
                Spacer()
                Button { model.shiftWeek(1) } label: { Image(systemName: "chevron.right") }
                    .accessibilityLabel("Next week")
                    .frame(minWidth: 44, minHeight: 44)
            }
            if typeSize.isAccessibilitySize {
                ScrollView(.horizontal) { dayButtons }
            } else {
                dayButtons
            }
        }
        .foregroundStyle(Palette.accentText)
    }

    private var dayButtons: some View {
        HStack(spacing: Spacing.hairline) {
            ForEach(model.week, id: \.self) { day in
                if let date = day.date(timeZone: model.calendar.timeZone) {
                    dayButton(day, date: date)
                        .frame(minWidth: typeSize.isAccessibilitySize ? 80 : nil)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plan.week")
    }

    private func dayButton(_ day: PlanDay, date: Date) -> some View {
        Button { model.selectedDay = day } label: {
            VStack(spacing: Spacing.tight) {
                Text(date, format: .dateTime.weekday(.narrow))
                    .font(Typography.caption)
                    .foregroundStyle(Palette.inkMuted)
                Text(date, format: .dateTime.day())
                    .font(Typography.title)
                    .foregroundStyle(day == model.selectedDay ? Palette.accentText : Palette.ink)
                Circle()
                    .fill(day == model.today ? Palette.accentText : .clear)
                    .frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(day == model.selectedDay ? Palette.accentSoft : .clear)
            .clipShape(RoundedRectangle(cornerRadius: Radius.control))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
        .accessibilityValue(day == model.today ? "Today" : "")
        .accessibilityAddTraits(day == model.selectedDay ? [.isSelected] : [])
        .accessibilityIdentifier("plan.day.\(day.rawValue)")
    }
}
