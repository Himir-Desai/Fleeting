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

    func getSnapshot(in _: Context, completion: @escaping (FreshnessEntry) -> Void) {
        let now = clock.now
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
            Text("Open Fleeting once to get started.")
                .font(.caption)
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
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Palette.ink)
            Text(entry.liveCount == 1 ? "thought" : "thoughts")
                .font(.caption)
                .foregroundStyle(Palette.inkMuted)

            Spacer(minLength: 0)

            if let fading = entry.fading {
                FreshnessBar(freshness: entry.fadingFreshness)
                Text(fading)
                    .font(.caption2)
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
                .font(.headline)
            if let fading = entry.fading {
                Text(fading)
                    .font(.caption2)
                    .lineLimit(2)
            }
        }
    }
}
