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
            Image(systemName: KindGlyph.name(for: receipt.kind ?? .unsorted))
                .font(Typography.caption)
                .foregroundStyle(Palette.accentText)
                .frame(width: 34, height: 34)
                .background {
                    RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                        .fill(Palette.accentSoft)
                }

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
