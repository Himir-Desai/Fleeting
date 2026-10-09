import SwiftUI

public extension View {
    /// Adds a glass keyboard-down accessory while this screen owns a focused input.
    func keyboardDismissControl(
        isFocused: Bool,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        modifier(KeyboardDismissControl(isFocused: isFocused, identifier: identifier, action: action))
            .trackKeyboardVisibility()
    }
}

private struct KeyboardDismissControl: ViewModifier {
    let isFocused: Bool
    let identifier: String
    let action: () -> Void
    @Environment(\.keyboardVisibility) private var keyboard

    func body(content: Content) -> some View {
        content
        #if os(iOS)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if isFocused, keyboard?.isVisible == true {
                HStack {
                    Spacer()
                    KeyboardDismissButton(action: action)
                        .accessibilityIdentifier(identifier)
                }
                .padding(.horizontal, Spacing.loose)
                .padding(.vertical, Spacing.regular)
            }
        }
        #endif
    }
}
