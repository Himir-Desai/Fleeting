import Core
import DesignSystem
import SwiftUI

/// Four round thought-type choices shared by thought properties and list defaults.
struct ThoughtKindPicker: View {
    let selection: ThoughtKind
    let identifier: String
    let onChoose: (ThoughtKind) -> Void

    var body: some View {
        HStack(spacing: Spacing.snug) {
            ForEach(ThoughtKind.allCases, id: \.self) { kind in
                RoundIconButton(
                    symbol: KindGlyph.name(for: kind),
                    label: KindGlyph.label(for: kind),
                    isSelected: selection == kind
                ) { onChoose(kind) }
                    .accessibilityIdentifier("\(identifier).\(kind.rawValue)")
            }
        }
    }
}
