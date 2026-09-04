import Core
import DesignSystem
import SwiftUI

/// The habits waiting for today's mark, sitting under the capture field on the home screen.
///
/// A horizontal run of cards rather than a list: this is the second thing on the screen, never the
/// first, and it has to be able to leave without the page reflowing around it (ADR-0047). It
/// disappears the moment the field takes focus, so capture is still a screen with nothing on it.
struct HabitStrip: View {
    /// State and rules for the habits shown here.
    @Bindable var model: DailyHabitsModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.snug) {
            SectionLabel("Today")
                .padding(.horizontal, Spacing.tight)

            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: Spacing.regular) {
                    ForEach(model.habits) { habit in
                        HabitCard(
                            thought: habit,
                            streak: model.streakCount(of: habit),
                            isKeptToday: model.isKeptToday(habit),
                            onMark: { Task { await model.markKept(habit) } }
                        )
                    }
                }
                .padding(.horizontal, Spacing.tight)
                .padding(.vertical, Spacing.tight)
            }
            .scrollIndicators(.hidden)
        }
        .accessibilityIdentifier("home.habits")
    }
}
