import Core
import DesignSystem
import SwiftUI

/// The card a saved thought collapses into for a moment before it goes.
///
/// The whole point of the animation: the field emptying proves the save happened, but says nothing
/// about where the thought went or that it has already started decaying. This says both, without a
/// tap and without blocking the next capture (ADR-0038).
struct CaptureReceiptCard: View {
    let receipt: CaptureReceipt

    var body: some View {
        HStack(spacing: Spacing.regular) {
            // A sprout rather than the kind's glyph: the receipt's moment is the thought taking
            // root, and the kind is already named in the line below (ADR-0042).
            GrowingSprout(size: 34)
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: Spacing.tight) {
                Text(receipt.body)
                    // The user's own words, so the serif (ADR-0037).
                    .font(Typography.serifBody)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)

                Text(receipt.summary)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.inkMuted)
            }

            Spacer(minLength: 0)
        }
        .padding(Spacing.inset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .fill(Palette.raised)
                .elevated(.card, cornerRadius: Radius.card)
        }
        // One element, read as one sentence: a receipt is not something to navigate through.
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("capture.receipt")
        .accessibilityLabel("Saved. \(receipt.body). \(receipt.summary)")
    }
}
