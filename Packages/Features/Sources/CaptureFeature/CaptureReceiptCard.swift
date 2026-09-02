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
        HStack(alignment: .top, spacing: Spacing.regular) {
            // A sprout rather than the kind's glyph: the receipt's moment is the thought taking
            // root, and the kind is already named in the line below (ADR-0042). It sits directly
            // on the card with no chip behind it, so it reads as drawn on the page rather than
            // stuck to it (ADR-0045).
            GrowingSprout(size: 30)
                .frame(width: 30, height: 30)

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
