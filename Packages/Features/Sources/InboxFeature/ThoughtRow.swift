import Core
import DesignSystem
import SwiftUI

/// One live thought in the inbox, its freshness read through weight rather than a meter: fresh
/// thoughts sit heavier and fuller, fading ones lighten (ADR-0025).
///
/// The opacity half of that fade is applied by ``InboxListRow`` to the whole row, so the kind
/// glyph and the inline action fade in step with the words rather than staying bright over a
/// faded thought.
struct ThoughtRow: View {
    let thought: Thought
    let freshness: Freshness
    let expiresAt: Date?

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.snug) {
            Text(thought.body)
                .font(Typography.body)
                .fontWeight(FreshnessStyle.weight(for: freshness.value))
                .foregroundStyle(Palette.ink)
                .lineLimit(typeSize.isAccessibilitySize ? 6 : 3)

            metadata
        }
        .padding(.vertical, Spacing.snug)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityValue(spokenFreshness)
    }

    /// The streak and when the thought archives. No meter — freshness is the text's own weight.
    @ViewBuilder
    private var metadata: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.tight))
            : AnyLayout(HStackLayout(alignment: .center, spacing: Spacing.regular))

        layout {
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

    /// How much life is left, in words, for VoiceOver — the band the weight is trying to convey.
    private var spokenFreshness: String {
        switch freshness.band {
        case .fresh: "fresh"
        case .settling: "settling"
        case .fading: "fading"
        case .expiring: "about to be archived"
        }
    }
}
