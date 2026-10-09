import Observation
import SwiftUI
#if os(iOS)
    import UIKit
#endif

/// Observable keyboard state for a page or modal presentation.
@MainActor
@Observable
public final class KeyboardVisibilityState {
    public fileprivate(set) var isVisible = false
    public init() {}
}

public extension EnvironmentValues {
    /// Keyboard state supplied by the nearest presentation observer.
    @Entry var keyboardVisibility: KeyboardVisibilityState? = nil
}

public extension View {
    /// Observes the software keyboard for this presentation and shares its visibility with its controls.
    func trackKeyboardVisibility() -> some View {
        modifier(KeyboardVisibility())
    }
}

private struct KeyboardVisibility: ViewModifier {
    @State private var keyboard = KeyboardVisibilityState()

    func body(content: Content) -> some View {
        content.environment(\.keyboardVisibility, keyboard)
        #if os(iOS)
            .onReceive(NotificationCenter.default
                .publisher(for: UIResponder.keyboardWillChangeFrameNotification))
            { note in
                guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
                      let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
                else { return }
                keyboard.isVisible = frame.height > 0 && frame.minY < scene.screen.bounds.maxY
            }
            .onReceive(NotificationCenter.default
                .publisher(for: UIResponder.keyboardWillHideNotification))
            { _ in
                keyboard.isVisible = false
            }
        #endif
    }
}
