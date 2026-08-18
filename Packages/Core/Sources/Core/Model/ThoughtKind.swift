import Foundation

/// What a captured thought turned out to be.
///
/// Kind affects exactly two things: how fast the thought decays, and which single next-step
/// affordance it offers. It does not fork the app into separate flows.
public enum ThoughtKind: String, CaseIterable, Codable, Sendable {
    /// Not yet classified. Every thought begins here.
    case unsorted
    /// Something worth developing further.
    case idea
    /// Something to do once.
    case todo
    /// Something to do repeatedly.
    case habit
}
