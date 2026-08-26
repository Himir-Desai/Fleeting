import Core
import SwiftUI

/// The symbol shown for each kind of thought.
enum KindGlyph {
    /// The SF Symbol name for a kind.
    /// - Parameter kind: The kind to represent.
    /// - Returns: A symbol name.
    static func name(for kind: ThoughtKind) -> String {
        switch kind {
        case .unsorted: "circle.dotted"
        case .idea: "lightbulb"
        case .todo: "checkmark.circle"
        case .habit: "repeat"
        }
    }

    /// A human label for a kind, used for accessibility and menus.
    /// - Parameter kind: The kind to describe.
    /// - Returns: A capitalised label.
    static func label(for kind: ThoughtKind) -> String {
        switch kind {
        case .unsorted: "Unsorted"
        case .idea: "Idea"
        case .todo: "Todo"
        case .habit: "Habit"
        }
    }
}
