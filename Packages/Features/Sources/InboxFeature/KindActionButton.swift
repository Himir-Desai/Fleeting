import Core
import DesignSystem
import SwiftUI

/// A thought's primary kind action: mark a to-do done, or keep a habit's streak.
///
/// A habit's button carries the drawn sprout rather than an SF Symbol, because the same action in
/// the list draws one and the two should not disagree (ADR-0042).
struct KindActionButton: View {
    /// What the button says.
    let label: String

    /// The SF Symbol to draw, for kinds that use one.
    let symbol: String

    /// Whether this is a habit, which is marked with the sprout instead.
    let isHabit: Bool

    /// What pressing it does.
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.snug) {
                if isHabit {
                    GrowingSprout(size: 22, tint: Palette.raised)
                        .frame(width: 22, height: 22)
                } else {
                    Image(systemName: symbol)
                }
                Text(label)
            }
            .font(Typography.title)
            .foregroundStyle(Palette.raised)
            .padding(.horizontal, Spacing.loose)
            .padding(.vertical, Spacing.regular)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .fill(Palette.accent)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("detail.kindAction")
        .accessibilityLabel(label)
    }
}
