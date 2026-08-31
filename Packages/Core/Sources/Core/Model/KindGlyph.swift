/// The symbol and label shown for each kind of thought.
///
/// Lives in `Core` rather than `DesignSystem` because it is keyed by a domain type, and the
/// design layer is not allowed to know the domain (ADR-0012). It lives here rather than in a
/// feature because three features now draw the same glyph, and features never import each
/// other. Nothing here is a colour or a metric — only names a view can resolve.
public enum KindGlyph {
    /// The SF Symbol name for a kind.
    /// - Parameter kind: The kind to represent.
    /// - Returns: A symbol name.
    public static func name(for kind: ThoughtKind) -> String {
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
    public static func label(for kind: ThoughtKind) -> String {
        switch kind {
        case .unsorted: "Unsorted"
        case .idea: "Idea"
        case .todo: "To-do"
        case .habit: "Habit"
        }
    }
}
