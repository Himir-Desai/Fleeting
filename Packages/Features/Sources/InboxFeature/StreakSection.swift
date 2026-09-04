import Core
import DesignSystem
import SwiftUI

/// A habit's streak, and the way to take back a mark made by mistake.
///
/// Marking a habit is one tap sitting in a list, so it is a tap people make by accident. Until
/// this existed the only way back was to let the whole streak lapse, which meant an accidental tap
/// cost a run the user had actually earned (ADR-0044).
///
/// The vine gains a leaf per day kept. It has room here that it did not have in a list row, so the
/// growth is legible rather than a scribble.
struct StreakSection: View {
    /// The streak being shown.
    let streak: Streak

    /// How often the habit is kept, so the run is counted in the right unit: a weekly habit kept
    /// four times is a four week streak, not a four day one (ADR-0048).
    let cadence: HabitCadence

    /// Takes back the most recent mark.
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: Spacing.regular) {
            VineRule(leaves: min(streak.count, 5), tint: Palette.accentText)
                .frame(width: 68)

            Text("\(streak.count) \(cadence.streakUnit(count: streak.count)) streak")
                .font(Typography.subtitle)
                .foregroundStyle(Palette.ink)

            Spacer(minLength: Spacing.snug)

            Button("Undo", action: onUndo)
                .font(Typography.caption)
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .tint(Palette.inkMuted)
                .accessibilityIdentifier("detail.undoStreak")
                .accessibilityLabel("Undo the last streak mark")
        }
    }
}
