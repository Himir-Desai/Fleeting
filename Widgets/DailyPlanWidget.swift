import Core
import DesignSystem
import SwiftUI
import WidgetKit

/// Today's checklist on the home screen and lock screen.
struct DailyPlanWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FleetingDailyPlan", provider: DailyPlanProvider(daysAhead: 0)) { entry in
            DailyPlanWidgetView(entry: entry, title: "Today")
                .containerBackground(Palette.surface, for: .widget)
                .widgetURL(URL(string: "fleeting://plan"))
        }
        .configurationDisplayName("Today's plan")
        .description("Check off today's tasks and catch up on earlier days.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
    }
}

/// Tomorrow's checklist, kept separate from today's commitments.
struct TomorrowPlanWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: "FleetingTomorrowPlan",
            provider: DailyPlanProvider(daysAhead: 1)
        ) { entry in
            DailyPlanWidgetView(entry: entry, title: "Tomorrow")
                .containerBackground(Palette.surface, for: .widget)
                .widgetURL(URL(string: "fleeting://plan?day=\(entry.day.rawValue)"))
        }
        .configurationDisplayName("Tomorrow's plan")
        .description("A little room for what you want to do tomorrow.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

/// The checklist's compact rendering, including an honest unavailable state.
struct DailyPlanWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DailyPlanEntry
    let title: String

    private var remaining: Int {
        entry.todos.filter { !$0.isDone }.count
    }

    var body: some View {
        if !entry.isReadable {
            if family == .accessoryCircular {
                Image(systemName: "checklist")
            } else {
                Text(entry
                    .isShared ? "Open Fleeting to load your plan." :
                    "Open Fleeting for your plan. Sharing isn’t available in this build.")
                    .font(Typography.caption)
            }
        } else if family == .accessoryCircular {
            VStack {
                Image(systemName: "checklist")
                Text("\(remaining)").font(Typography.title)
            }
            .accessibilityLabel("\(remaining) tasks left today; \(entry.reviewCount) to review")
        } else if family == .accessoryRectangular {
            VStack(alignment: .leading) {
                Text("\(remaining) left today").font(Typography.title)
                if entry.reviewCount > 0 {
                    Text("\(entry.reviewCount) to review").font(Typography.caption)
                } else if let next = entry.todos.first(where: { !$0.isDone }) {
                    Text(next.text).font(Typography.caption).lineLimit(1)
                }
            }
        } else {
            checklist
        }
    }

    private var checklist: some View {
        VStack(alignment: .leading, spacing: Spacing.snug) {
            HStack {
                Text(title).font(Typography.title)
                Spacer()
                Text("\(remaining) left").font(Typography.caption).foregroundStyle(Palette.inkMuted)
            }
            if entry.todos.isEmpty {
                Text("Room for a fresh start.").font(Typography.serifBody).foregroundStyle(Palette.inkMuted)
            }
            ForEach(Array(entry.todos.prefix(family == .systemSmall ? 2 : 3))) { todo in
                Button(intent: CompleteDailyTodoIntent(taskID: todo.id.uuidString)) {
                    HStack(spacing: Spacing.snug) {
                        Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                        Text(todo.text).font(Typography.caption).strikethrough(todo.isDone).lineLimit(1)
                    }
                }
                .buttonStyle(.plain)
                .disabled(todo.isDone)
                .accessibilityLabel("\(todo.isDone ? "Done" : "Mark done"): \(todo.text)")
            }
            Spacer(minLength: 0)
            if entry.reviewCount > 0, let url = URL(string: "fleeting://daily-review") {
                Link("\(entry.reviewCount) to review", destination: url)
                    .font(Typography.caption).foregroundStyle(Palette.accentText)
            }
        }
        .foregroundStyle(Palette.ink)
    }
}
