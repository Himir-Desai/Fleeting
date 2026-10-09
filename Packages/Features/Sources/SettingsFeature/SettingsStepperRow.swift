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

    /// The visible circle inside an independent 44-point tap target.
    private let controlSize: CGFloat = 32

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.snug) {
                heading.fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: Spacing.snug)
                valueText.fixedSize()
                controls
            }
            VStack(alignment: .leading, spacing: Spacing.snug) {
                heading
                ViewThatFits(in: .horizontal) {
                    HStack {
                        valueText.fixedSize()
                        Spacer(minLength: Spacing.snug)
                        controls
                    }
                    VStack(alignment: .leading, spacing: Spacing.snug) {
                        valueText
                        controls
                    }
                }
            }
        }
        // Each step control names the value it changes and remains independently reachable.
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }

    private var heading: some View {
        HStack(spacing: Spacing.snug) {
            if let symbol {
                Image(systemName: symbol).font(Typography.secondarySymbol)
                    .foregroundStyle(Palette.inkMuted)
                    .frame(width: Spacing.loose)
            }
            Text(label).font(Typography.body).foregroundStyle(Palette.ink)
        }
    }

    private var valueText: some View {
        Text(value).font(Typography.body).foregroundStyle(Palette.inkMuted).monospacedDigit()
    }

    private var controls: some View {
        HStack(spacing: Spacing.tight) {
            stepButton("minus", action: onDecrease)
            stepButton("plus", action: onIncrease)
        }
    }

    /// One round step control.
    private func stepButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(Typography.controlSymbol)
                .foregroundStyle(Palette.accentText)
                .frame(width: controlSize, height: controlSize)
                .background { Circle().fill(Palette.surfaceSunken) }
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(.rect)
        }
        .buttonStyle(PressFeedbackStyle())
        .accessibilityLabel("\(symbol == "plus" ? "Increase" : "Decrease") \(label)")
    }
}
