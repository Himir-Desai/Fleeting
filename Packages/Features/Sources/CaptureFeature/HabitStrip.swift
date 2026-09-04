import Core
import DesignSystem
import SwiftUI

/// The habits waiting to be kept, sitting under the capture field on the home screen.
///
/// A vertical stack, so every outstanding habit is readable at a glance rather than hidden off
/// the trailing edge (ADR-0048). It is the second thing on the screen, never the first, and
/// disappears the moment the field takes focus so capture is still a screen with nothing on it.
///
/// The list is short by construction: only habits actually due appear, and each one leaves as it
/// is marked, so the stack empties as the day is worked through.
struct HabitStrip: View {
    /// State and rules for the habits shown here.
    @Bindable var model: DailyHabitsModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.snug) {
            SectionLabel(model.habits.count == 1 ? "1 habit due" : "\(model.habits.count) habits due")
                .padding(.horizontal, Spacing.tight)

            // Scrolls only when there are more habits than fit; the stack itself is the layout,
            // so a short list sits still rather than living inside a scroll view that can drift.
            ScrollView(.vertical) {
                VStack(spacing: Spacing.snug) {
                    ForEach(model.habits) { habit in
                        HabitCard(
                            thought: habit,
                            streak: model.streakCount(of: habit),
                            cadence: model.cadence(of: habit),
                            onMark: { Task { await model.markKept(habit) } }
                        )
                        .transition(.asymmetric(
                            insertion: .opacity,
                            // A kept habit leaves towards the trailing edge, which reads as
                            // being filed away rather than as the list glitching.
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                    }
                }
                .padding(.horizontal, Spacing.tight)
                .padding(.vertical, Spacing.tight)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
        }
        .motion(Motion.commit, value: model.habits.map(\.id))
        .accessibilityIdentifier("home.habits")
    }
}
