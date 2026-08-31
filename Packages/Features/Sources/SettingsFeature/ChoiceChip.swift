import DesignSystem
import SwiftUI

/// One option in a small set, drawn as a filled capsule when chosen.
///
/// The same selected/unselected language as the inbox's filter chips and capture's type icons,
/// so a choice reads the same wherever the app offers one.
struct ChoiceChip: View {
    /// The option's name.
    let label: String
    /// Whether this is the current choice.
    let isSelected: Bool
    /// Called when the chip is tapped.
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(Typography.subtitle)
                .foregroundStyle(isSelected ? Palette.raised : Palette.ink)
                .padding(.horizontal, Spacing.inset)
                .padding(.vertical, Spacing.snug)
                .background {
                    Capsule().fill(isSelected ? Palette.accent : Palette.surfaceSunken)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}
