import DesignSystem
import SwiftUI

/// The three decisions a review card offers: let go, snooze, keep.
///
/// One equal-weight row rather than two quiet buttons and one prominent one. All three are real
/// decisions and the screen should not lean on the user's arm toward any of them (ADR-0040); Keep
/// keeps only its tint, so the eye can find it without the layout arguing for it.
///
/// Its own file rather than a property of `ReviewView`, which was over the project's length limit
/// with it inline.
struct ReviewDecisions: View {
    /// Archives the thought.
    let onLetGo: () -> Void
    /// Holds the thought at full freshness for a week.
    let onSnooze: () -> Void
    /// Resets the thought's freshness.
    let onKeep: () -> Void

    var body: some View {
        // Three capsules stop fitting well before the largest type size, so the row becomes a
        // column when it has to.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.snug) {
                letGo
                snooze
                keep
            }
            VStack(spacing: Spacing.snug) {
                keep
                snooze
                letGo
            }
        }
        .font(Typography.body)
    }

    private var letGo: some View {
        button("Let go", tint: Palette.inkMuted, identifier: "review.drop", action: onLetGo)
            .accessibilityHint("Moves this to the archive. Nothing is deleted.")
    }

    private var snooze: some View {
        button("Snooze", tint: Palette.inkMuted, identifier: "review.snooze", action: onSnooze)
            .accessibilityHint("Holds this at full freshness for a week")
    }

    private var keep: some View {
        button("Keep", tint: Palette.accentText, identifier: "review.act", action: onKeep)
            .accessibilityHint("Resets how fresh this thought is")
    }

    /// One decision: the same shape and weight as the other two, differing only in tint.
    /// - Parameters:
    ///   - title: The word on the button.
    ///   - tint: Its colour.
    ///   - identifier: The accessibility identifier the UI tests address it by.
    ///   - action: What deciding does.
    /// - Returns: The button.
    private func button(
        _ title: String,
        tint: Color,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(title, action: action)
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .tint(tint)
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier(identifier)
    }
}
