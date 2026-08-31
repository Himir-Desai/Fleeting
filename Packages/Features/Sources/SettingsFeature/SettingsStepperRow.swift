import DesignSystem
import SwiftUI

/// A labelled value with a minus and a plus, for a number that is adjusted rather than typed.
///
/// Used for the decay lifetimes and the nudge hour. A stepper rather than a wheel because these
/// are nudged by one or two, not scrolled to from far away, and a wheel inside a scrolling page
/// fights the scroll.
struct SettingsStepperRow: View {
    /// The row's name.
    let label: String
    /// An optional glyph shown before the name.
    var symbol: String?
    /// The current value, already formatted.
    let value: String
    /// Called when the minus is tapped.
    let onDecrease: () -> Void
    /// Called when the plus is tapped.
    let onIncrease: () -> Void

    /// The round tap targets, grown with the type size to stay reachable.
    @ScaledMetric(relativeTo: .body) private var controlSize: CGFloat = 32

    var body: some View {
        HStack(spacing: Spacing.snug) {
            if let symbol {
                Image(systemName: symbol)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.inkMuted)
                    .frame(width: Spacing.loose)
            }

            Text(label)
                .font(Typography.body)
                .foregroundStyle(Palette.ink)

            Spacer(minLength: Spacing.snug)

            Text(value)
                .font(Typography.body)
                .foregroundStyle(Palette.inkMuted)
                .monospacedDigit()

            HStack(spacing: Spacing.tight) {
                stepButton("minus", action: onDecrease)
                stepButton("plus", action: onIncrease)
            }
        }
        // One element to VoiceOver, with the two buttons as adjustable actions rather than as
        // two unlabelled glyphs read after the value.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }

    /// One round step control.
    private func stepButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(Typography.caption)
                .foregroundStyle(Palette.accentText)
                .frame(width: controlSize, height: controlSize)
                .background { Circle().fill(Palette.surfaceSunken) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(symbol == "plus" ? "Increase" : "Decrease")
    }
}
