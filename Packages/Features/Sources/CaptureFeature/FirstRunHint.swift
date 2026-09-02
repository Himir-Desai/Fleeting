import DesignSystem
import SwiftUI

/// The one-time explanation of what makes this app different.
///
/// A line of text under the field, not a screen in front of it. It can be read, ignored, or
/// dismissed, and it never takes focus or delays a capture (ADR-0008, ADR-0021).
struct FirstRunHint: View {
    /// The dismiss control's tap target, which has to clear 44pt at every type size.
    @ScaledMetric(relativeTo: .caption) private var dismissSize: CGFloat = 44

    /// Called when the user dismisses the hint.
    let onDismiss: () -> Void

    var body: some View {
        // No identifier on the stack: an identifier on a container overrides the ones its
        // children set, which would hide the dismiss control from the tests that drive it.
        HStack(alignment: .top, spacing: Spacing.snug) {
            Text("Thoughts fade as they age and file themselves away. Nothing is ever deleted.")
                .font(Typography.caption)
                .foregroundStyle(Palette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
                // Capped, because at the accessibility sizes this line grew to fill the whole
                // page: with the keyboard over the tab bar there was then no way off the capture
                // screen at all. An explanation that traps you is worse than no explanation.
                .lineLimit(4)
                .accessibilityIdentifier("capture.hint")

            Button("Got it", action: onDismiss)
                .font(Typography.caption)
                .tint(Palette.accentText)
                .frame(minWidth: dismissSize, minHeight: dismissSize)
                .contentShape(.rect)
                .accessibilityIdentifier("capture.hint.dismiss")
        }
        .padding(.vertical, Spacing.tight)
    }
}
