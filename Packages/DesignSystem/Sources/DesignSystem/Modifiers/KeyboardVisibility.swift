import Observation
import SwiftUI
#if os(iOS)
    import UIKit
#endif

/// Observable keyboard state for a page or modal presentation.
@MainActor
@Observable
public final class KeyboardVisibilityState {
    /// The keyboard snapshot shared by pages and stacked presentations.
    public static let shared = KeyboardVisibilityState()
    public private(set) var isVisible = false
    public init() {}

    /// Reconciles visibility with the active window's current keyboard geometry.
    public func refresh() {
        #if os(iOS)
            guard let window = activeWindow else { return }
            let frame = window.keyboardLayoutGuide.layoutFrame
            isVisible = frame.height > window.safeAreaInsets.bottom + 1
                && frame.minY < window.bounds.maxY
        #endif
    }

    #if os(iOS)
        private var activeWindow: UIWindow? {
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                .filter { $0.activationState == .foregroundActive }
                .flatMap(\.windows).first { $0.isKeyWindow }
        }

        fileprivate func update(from notification: Notification) {
            guard let window = activeWindow,
                  let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
            else { refresh(); return }
            let local = window.convert(frame, from: window.screen.coordinateSpace)
            let overlap = window.bounds.intersection(local)
            isVisible = !overlap.isNull && overlap.height > window.safeAreaInsets.bottom + 1
        }
    #endif
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
    @State private var keyboard = KeyboardVisibilityState.shared
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content.environment(\.keyboardVisibility, keyboard)
        #if os(iOS)
            .onReceive(NotificationCenter.default
                .publisher(for: UIResponder.keyboardWillChangeFrameNotification))
            { note in
                keyboard.update(from: note)
            }
            .onReceive(NotificationCenter.default
                .publisher(for: UIResponder.keyboardDidChangeFrameNotification))
            { note in keyboard.update(from: note) }
            .onReceive(NotificationCenter.default
                .publisher(for: UIResponder.keyboardDidHideNotification))
            { _ in
                keyboard.refresh()
            }
            .onAppear { keyboard.refresh() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    keyboard.refresh()
                }
            }
        #endif
    }
}
