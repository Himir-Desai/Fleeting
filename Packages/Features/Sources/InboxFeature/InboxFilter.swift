import Core

/// Which slice of the collection the Thoughts page is showing.
///
/// The kind cases and "All" draw from the live list; "Archived" swaps to thoughts that have left
/// play. Archived thoughts never appear under All (ADR-0026).
public enum InboxFilter: Hashable, Sendable {
    /// Every live thought, regardless of kind.
    case all
    /// Live thoughts of one kind.
    case kind(ThoughtKind)
    /// Thoughts that have expired or been set aside.
    case archived
}
