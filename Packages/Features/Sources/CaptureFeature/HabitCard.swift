import Core
import DesignSystem
import SwiftUI

/// One habit's card on the home screen: what it is, how long the run is, and one tap to keep it.
///
/// The sprout is the control, as it is in the list (ADR-0042). A habit already kept today shows a
/// filled tick instead and stops being tappable, so the card says "done" rather than inviting a
/// tap that would change nothing.
struct HabitCard: View {
    /// The habit being shown.
    let thought: Thought

    /// How many consecutive days it has been kept.
    let streak: Int

    /// Whether today's mark has already been made.
    let isKeptToday: Bool

    /// Records today's mark.
    let onMark: () -> Void

    /// The mark control's tap target, which has to clear 44pt at every type size.
    @ScaledMetric(relativeTo: .body) private var controlSize: CGFloat = 44

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.snug) {
            Text(thought.title ?? thought.body)
                .font(Typography.subtitle)
                .foregroundStyle(Palette.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .center, spacing: Spacing.snug) {
                Text(streakLine)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.inkMuted)

                Spacer(minLength: Spacing.tight)

                markControl
            }
        }
        .frame(width: 200, alignment: .leading)
        .padding(Spacing.inset)
        .background {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .fill(Palette.raised)
                .elevated(.card, cornerRadius: Radius.card)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.habit")
    }

    /// The run, in the words the detail screen uses.
    private var streakLine: String {
        streak == 0 ? "Not started" : "\(streak) day streak"
    }

    /// The one tap the card offers: keep the streak, or a tick saying today is already done.
    @ViewBuilder
    private var markControl: some View {
        if isKeptToday {
            Image(systemName: "checkmark.circle.fill")
                .font(Typography.title)
                .foregroundStyle(Palette.accentText)
                .frame(width: controlSize, height: controlSize)
                .accessibilityIdentifier("home.habit.kept")
                .accessibilityLabel("Kept today")
        } else {
            Button(action: onMark) {
                GrowingSprout(size: 26)
                    .frame(width: controlSize, height: controlSize)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.habit.mark")
            .accessibilityLabel("Continue streak")
        }
    }
}
