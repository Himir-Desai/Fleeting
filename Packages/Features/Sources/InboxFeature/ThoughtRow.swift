import Core
import DesignSystem
import SwiftUI

/// One live thought in the inbox, faded in proportion to how much freshness it has left.
struct ThoughtRow: View {
    let thought: Thought
    let freshness: Freshness
    let expiresAt: Date?

    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var typeSize

    /// The meter's width, so it grows with the text beside it rather than staying a hairline
    /// against 60pt type.
    @ScaledMetric(relativeTo: .caption) private var meterWidth: CGFloat = 72

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.snug) {
            Text(thought.body)
                .font(Typography.emphasis)
                .foregroundStyle(Palette.ink)
                .lineLimit(typeSize.isAccessibilitySize ? 6 : 3)

            metadata
        }
        .opacity(FreshnessStyle.opacity(for: freshness.value, increasedContrast: isHighContrast))
        .motion(Motion.decay, value: freshness.value)
        .padding(.vertical, Spacing.snug)
        .accessibilityElement(children: .combine)
        .accessibilityValue(spokenFreshness)
    }

    /// The meter, the streak, and when the thought archives.
    ///
    /// Laid out down the screen at accessibility type sizes, because three items side by side at
    /// 60pt leaves no room for any of them.
    @ViewBuilder
    private var metadata: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.snug))
            : AnyLayout(HStackLayout(alignment: .center, spacing: Spacing.regular))

        layout {
            FreshnessMeter(freshness: freshness.value)
                .frame(width: meterWidth)

            if let streak = thought.streak, streak.hasStarted {
                Text("\(streak.count) day streak")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.accentText)
            }

            if let expiresAt {
                Text("archives \(expiresAt, format: .relative(presentation: .named))")
                    .font(Typography.caption)
                    .foregroundStyle(
                        freshness.band == .expiring ? Palette.fading : Palette.inkMuted
                    )
            }
        }
    }

    /// Whether the fade should be suppressed in favour of readable text.
    private var isHighContrast: Bool {
        contrast == .increased
    }

    /// How much life is left, in words.
    ///
    /// VoiceOver reads the row's text and its "archives in" label already; a percentage on top of
    /// that is noise. The band is the thing the fade is trying to say.
    private var spokenFreshness: String {
        switch freshness.band {
        case .fresh: "fresh"
        case .settling: "settling"
        case .fading: "fading"
        case .expiring: "about to be archived"
        }
    }
}
