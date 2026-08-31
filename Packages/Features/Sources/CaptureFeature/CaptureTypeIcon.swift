import Core
import DesignSystem
import SwiftUI

/// One selectable thought-type in the capture controls: an icon on a chip, with no caption.
///
/// Sits in the row between the advanced-options and save buttons. The selected type fills with the
/// accent; the rest are quiet.
struct CaptureTypeIcon: View {
    /// The type this icon selects, or `nil` for automatic sorting.
    let kind: ThoughtKind?
    /// Whether this is the current choice.
    let isSelected: Bool
    /// The icon chip's diameter.
    let size: CGFloat
    /// Called when the icon is tapped.
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: Self.symbol(for: kind))
                .font(Typography.body)
                .foregroundStyle(isSelected ? Palette.raised : Palette.inkMuted)
                .frame(width: size, height: size)
                .background {
                    Circle().fill(isSelected ? Palette.accent : Palette.surfaceSunken)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Self.label(for: kind))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// The SF Symbol for a type choice.
    static func symbol(for kind: ThoughtKind?) -> String {
        switch kind {
        case .none: "sparkles"
        case .unsorted: "circle.dotted"
        case .idea: "lightbulb"
        case .todo: "checkmark.circle"
        case .habit: "repeat"
        }
    }

    /// The spoken name for a type choice.
    static func label(for kind: ThoughtKind?) -> String {
        switch kind {
        case .none: "Let the app sort it"
        case .unsorted: "Unsorted"
        case .idea: "Idea"
        case .todo: "To-do"
        case .habit: "Habit"
        }
    }
}
