import SwiftUI

/// The same glass keyboard-down control wherever typing is available.
public struct KeyboardDismissButton: View {
    private let action: () -> Void

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: "keyboard.chevron.compact.down")
                .font(Typography.controlSymbol)
                .frame(width: 52, height: 52)
        }
        .buttonStyle(PressFeedbackStyle())
        .foregroundStyle(Palette.accentText)
        .floatingGlass()
        .accessibilityLabel("Hide keyboard")
    }
}
