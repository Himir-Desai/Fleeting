import SwiftUI

/// A round icon choice or action, with optional selected fill and visible caption.
public struct RoundIconButton: View {
    private let symbol: String
    private let label: String
    private let tint: Color
    private let isSelected: Bool
    private let showsLabel: Bool
    private let role: ButtonRole?
    private let action: () -> Void

    public init(
        symbol: String, label: String, tint: Color = Palette.inkMuted,
        isSelected: Bool = false, showsLabel: Bool = false,
        role: ButtonRole? = nil, action: @escaping () -> Void
    ) {
        self.symbol = symbol
        self.label = label
        self.tint = tint
        self.isSelected = isSelected
        self.showsLabel = showsLabel
        self.role = role
        self.action = action
    }

    public var body: some View {
        Button(role: role, action: action) {
            VStack(spacing: Spacing.snug) {
                Image(systemName: symbol)
                    .font(Typography.controlSymbol)
                    .foregroundStyle(isSelected ? Palette.onAccent : tint)
                    .frame(width: 52, height: 52)
                    .background { Circle().fill(isSelected ? Palette.accent : Palette.surfaceSunken) }
                if showsLabel {
                    Text(label).font(Typography.caption).foregroundStyle(Palette.inkMuted)
                }
            }
        }
        .buttonStyle(PressFeedbackStyle())
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
