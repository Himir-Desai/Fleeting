import Core
import DesignSystem
import SwiftUI

/// One habit's card on the home screen: what it is, how often, how long the run is, and one tap
/// to keep it.
///
/// The sprout is the control, as it is in the list (ADR-0042). There is no "kept" state to draw:
/// a habit marked for its period stops being due and leaves the screen entirely (ADR-0048).
struct HabitCard: View {
    /// The habit being shown.
    let thought: Thought

    /// How many consecutive periods it has been kept.
    let streak: Int

    /// How often it is meant to be kept.
    let cadence: HabitCadence

    /// Records this period's mark.
    let onMark: () -> Void

    /// The mark control's tap target, which has to clear 44pt at every type size.
    @ScaledMetric(relativeTo: .body) private var controlSize: CGFloat = 44

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.regular) {
            VStack(alignment: .leading, spacing: Spacing.tight) {
                Text(thought.title ?? thought.body)
                    .font(Typography.subtitle)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(caption)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.inkMuted)
            }

            Spacer(minLength: Spacing.snug)

            Button(action: onMark) {
                GrowingSprout(size: 26)
                    .frame(width: controlSize, height: controlSize)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.habit.mark")
            .accessibilityLabel("Keep \(thought.title ?? thought.body)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.inset)
        .background {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .fill(Palette.raised)
                .elevated(.card, cornerRadius: Radius.card)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.habit")
    }

    /// How often, and how long the run is. The cadence is always said, because "4 weeks" only
    /// means something once you know the habit is weekly.
    private var caption: String {
        guard streak >= 1 else { return cadence.label }
        return "\(cadence.label) · \(streak) \(cadence.streakUnit(count: streak)) streak"
    }
}
