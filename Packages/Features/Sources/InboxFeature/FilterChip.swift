import DesignSystem
import SwiftUI

/// One pill in the Thoughts page's filter row: an icon, a label, and an optional count.
///
/// Uses the same selected/unselected colouring as the capture type icons — an accent fill when
/// active, a sunken chip when not — so the two screens read as one system.
struct FilterChip: View {
    /// The SF Symbol shown before the label.
    let systemImage: String
    /// The chip's name.
    let label: String
    /// A count shown after the label, or `nil` for none.
    var count: Int?
    /// Whether this chip is the active filter.
    let isSelected: Bool
    /// Called when the chip is tapped.
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.tight) {
                Image(systemName: systemImage)
                Text(label)
                if let count {
                    Text("\(count)")
                        .foregroundStyle(isSelected ? Palette.raised.opacity(0.8) : Palette.inkMuted)
                }
            }
            .font(Typography.subtitle)
            .foregroundStyle(isSelected ? Palette.raised : Palette.ink)
            .padding(.horizontal, Spacing.regular)
            .padding(.vertical, Spacing.snug)
            .background {
                Capsule().fill(isSelected ? Palette.accent : Palette.surfaceSunken)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(count.map { "\(label), \($0)" } ?? label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
