import Core
import DesignSystem
import SwiftUI
import WidgetKit

/// Supplies freshness entries, refreshed hourly.
struct FreshnessProvider: TimelineProvider {
    private let clock = SystemClock()

    func placeholder(in _: Context) -> FreshnessEntry {
        .placeholder(at: clock.now)
    }

    func getSnapshot(in context: Context, completion: @escaping (FreshnessEntry) -> Void) {
        let now = clock.now
        guard !context.isPreview else {
            completion(.placeholder(at: now))
            return
        }
        let finish = WidgetCompletion(completion)
        Task { await finish(WidgetStore.entry(at: now)) }
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<FreshnessEntry>) -> Void) {
        let now = clock.now
        let finish = WidgetCompletion(completion)
        Task {
            let entry = await WidgetStore.entry(at: now)
            // Freshness changes continuously but slowly; hourly is enough to keep the fade honest
            // without spending the widget's refresh budget.
            let next = now.addingTimeInterval(3600)
            finish(Timeline(entries: [entry], policy: .after(next)))
        }
    }
}

/// Shows how much is still live, and what is closest to being lost.
struct FreshnessWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FleetingFreshness", provider: FreshnessProvider()) { entry in
            FreshnessWidgetView(entry: entry)
                .containerBackground(Palette.surface, for: .widget)
                .widgetURL(URL(string: "fleeting://capture"))
        }
        .configurationDisplayName("Fleeting")
        .description("How much is still live, and what is fading fastest.")
        .supportedFamilies([.systemSmall, .accessoryRectangular])
    }
}

/// The freshness widget's content.
struct FreshnessWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FreshnessEntry

    var body: some View {
        if !entry.isReadable {
            Text(entry.isShared
                ? "Thoughts couldn’t load. Open Fleeting to try again."
                : "Thoughts aren’t available in this widget with this build. Tap to capture.")
                .font(Typography.caption)
                .foregroundStyle(Palette.inkMuted)
        } else if family == .accessoryRectangular {
            lockScreen
        } else {
            home
        }
    }

    /// The home screen treatment: a count, and the thought closest to archiving.
    private var home: some View {
        VStack(alignment: .leading, spacing: Spacing.snug) {
            Text("\(entry.liveCount)")
                .font(Typography.numeral)
                .foregroundStyle(Palette.ink)
            SectionLabel(entry.liveCount == 1 ? "thought" : "thoughts")

            Spacer(minLength: 0)

            if let fading = entry.fading {
                FreshnessMeter(freshness: entry.fadingFreshness, thickness: 4)
                Text(fading)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.inkMuted)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The lock screen treatment, which has to survive being rendered in a single tint.
    private var lockScreen: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(entry.liveCount) live")
                .font(Typography.title)
            if let fading = entry.fading {
                Text(fading)
                    .font(Typography.caption)
                    .lineLimit(2)
            }
        }
    }
}
