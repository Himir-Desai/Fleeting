import SwiftUI

/// Gives custom controls immediate press feedback without moving their tap targets.
public struct PressFeedbackStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(!isEnabled ? 0.45 : (configuration.isPressed ? 0.55 : 1))
    }
}
