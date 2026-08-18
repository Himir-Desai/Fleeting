import Foundation

/// The only notifications the app is permitted to send.
///
/// The list is closed on purpose: ADR-0009 caps the app at these three, and adding a
/// fourth requires a new ADR rather than a new case.
public enum NudgeKind: String, CaseIterable, Sendable {
    /// One forgotten thought, resurfaced with copy written by the on-device model.
    case dailyResurface
    /// The weekly invitation to review. An invitation, never a demand.
    case weeklyReview
    /// A heads-up that a thought is a few days from archiving.
    case expiryWarning
}
