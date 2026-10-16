import Core
import DesignSystem
import SwiftUI

/// Thought text with constant typography, completion strikethrough and expiry metadata.
struct ThoughtRow: View {
    let thought: Thought
    let freshness: Freshness
    let expiresAt: Date?

    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.snug) {
            Text(thought.body)
                // The user's own words, so the serif (ADR-0037).
                .font(Typography.serifBody)
                .strikethrough(thought.isCompleted)
                .foregroundStyle(Palette.ink)
                .lineLimit(typeSize.isAccessibilitySize ? 6 : 3)
                .opacity(FreshnessStyle.opacity(
                    for: freshness.value,
                    increasedContrast: contrast == .increased
                ))

            metadata
        }
        .padding(.vertical, Spacing.snug)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityValue(spokenFreshness)
    }

    /// The streak and when the thought archives.
    @ViewBuilder
    private var metadata: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.tight))
            : AnyLayout(HStackLayout(alignment: .center, spacing: Spacing.regular))

        layout {
            if let streak = thought.streak, streak.hasStarted {
                // No vine here. It was tried at 34pt beside this label and read as a scribble
                // rather than a plant — a line drawing needs room, and a list row has none. The
                // habit's growth is carried by the sprout in its action chip instead (ADR-0042).
                Text("\(streak.count) \(thought.cadence.streakUnit(count: streak.count)) streak")
                    .font(Typography.caption)
                    // Muted, not accent: a streak is a fact about the thought, and the accent is
                    // reserved for time and action (ADR-0041).
                    .foregroundStyle(Palette.inkMuted)
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

    /// Completion or remaining freshness, in words, for VoiceOver.
    private var spokenFreshness: String {
        if thought.isCompleted {
            return "Done"
        }
        return switch freshness.band {
        case .fresh: "fresh"
        case .settling: "settling"
        case .fading: "fading"
        case .expiring: "about to be archived"
        }
    }
}
