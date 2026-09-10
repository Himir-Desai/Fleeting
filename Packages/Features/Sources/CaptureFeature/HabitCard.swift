import Core
import DesignSystem
import SwiftUI

/// One habit's card on the home screen: what it is, how often, how long the run is, and one tap
/// to keep it.
///
/// Pressing the sprout grows it, the way the mark grows everywhere else in the app (ADR-0042),
/// and only then does the card leave — sliding down and fading, the same exit a saved thought's
/// receipt makes (ADR-0051). The mark is the confirmation, so the card must still be on screen to
/// carry it: a card that vanished on touch would take the acknowledgement with it.
struct HabitCard: View {
    /// The habit being shown.
    let thought: Thought

    /// How many consecutive periods it has been kept.
    let streak: Int

    /// How often it is meant to be kept.
    let cadence: HabitCadence

    /// Records this period's mark. Called once the sprout has finished growing.
    let onMark: () -> Void

    /// How far the sprout has grown, 0 until the card is pressed.
    @State private var growth: Double = 0

    /// Whether the mark is already under way, so a second tap cannot start it twice.
    @State private var isKeeping = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

            Button(action: keep) {
                // Drawn at its own progress rather than by `GrowingSprout`, which grows on
                // appear. Here the growth is the response to the press, so the card shows a
                // faint fully-drawn sprout at rest — the control has to look like a control —
                // and redraws it in full colour as the tap lands.
                ZStack {
                    SproutMark(progress: 1, tint: Palette.inkMuted.opacity(0.4))
                        .opacity(growth > 0 ? 0 : 1)
                    SproutMark(progress: growth)
                }
                .frame(width: 26, height: 26)
                .frame(width: controlSize, height: controlSize)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .disabled(isKeeping)
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

    /// Grows the sprout, then records the mark.
    ///
    /// The write is deferred until the drawing finishes so the card is still there to show it.
    /// Under Reduce Motion the mark is recorded immediately: the answer to "no motion" is the end
    /// state, never a wait for an animation that is not playing (ADR-0020).
    private func keep() {
        guard !isKeeping else { return }
        isKeeping = true

        guard !reduceMotion else {
            growth = 1
            onMark()
            return
        }

        withAnimation(Motion.growth) { growth = 1 }
        Task {
            try? await Task.sleep(for: .seconds(0.85))
            onMark()
        }
    }
}
