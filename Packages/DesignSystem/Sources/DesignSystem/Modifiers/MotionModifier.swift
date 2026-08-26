import SwiftUI

/// Animates a change unless the system has asked for reduced motion.
private struct Motioned<Value: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation
    let value: Value

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}

public extension View {
    /// Animates this view when a value changes, honouring Reduce Motion.
    ///
    /// The single place animation is applied, so honouring the setting is not something each
    /// screen has to remember.
    /// - Parameters:
    ///   - animation: One of the ``Motion`` timings.
    ///   - value: The value whose change drives the animation.
    /// - Returns: The view, animated or not.
    func motion(_ animation: Animation, value: some Equatable) -> some View {
        modifier(Motioned(animation: animation, value: value))
    }
}
