import Core
import DesignSystem
import SwiftUI

/// One live thought in the inbox, faded in proportion to how much freshness it has left.
struct ThoughtRow: View {
    let thought: Thought
    let freshness: Freshness
    let expiresAt: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.snug) {
            Text(thought.body)
                .font(Typography.body)
                .foregroundStyle(Palette.ink)
                .lineLimit(3)

            HStack(spacing: Spacing.snug) {
                FreshnessBar(freshness: freshness.value)
                    .frame(width: 56)

                if let expiresAt {
                    Text("archives \(expiresAt, format: .relative(presentation: .named))")
                        .font(Typography.caption)
                        .foregroundStyle(
                            freshness.band == .expiring ? Palette.fading : Palette.inkMuted
                        )
                }
            }
        }
        .opacity(FreshnessStyle.opacity(for: freshness.value))
        .padding(.vertical, Spacing.tight)
        .accessibilityElement(children: .combine)
        .accessibilityValue("freshness \(Int(freshness.value * 100)) percent")
    }
}
