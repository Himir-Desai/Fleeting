import DesignSystem
import SwiftUI

/// Explicit actions on a thought, using the same controls as daily task review.
struct ReviewDecisions: View {
    let hideTitle: String
    let identifierSuffix: String
    let onArchive: () -> Void
    let onHide: () -> Void
    let onKeepActive: () -> Void
    var canArchive = true

    var body: some View {
        ReviewActionRow(stacked: true) {
            ReviewAction(
                "Keep active",
                symbol: "arrow.clockwise",
                tint: Palette.accentText,
                action: onKeepActive
            )
            .accessibilityIdentifier("review.act\(identifierSuffix)")
            .accessibilityHint("Keeps this visible and restarts its freshness")
            ReviewAction(
                hideTitle,
                symbol: "clock.arrow.circlepath",
                tint: Palette.inkMuted,
                action: onHide
            )
            .accessibilityIdentifier("review.snooze\(identifierSuffix)")
            .accessibilityHint("Hides this until its reminder date, then returns it to Thoughts")
            ReviewAction("Archive", symbol: "archivebox", tint: Palette.inkMuted, action: onArchive)
                .disabled(!canArchive)
                .accessibilityIdentifier("review.archive\(identifierSuffix)")
                .accessibilityHint("Moves this to Archived without deleting it")
        }
    }
}
