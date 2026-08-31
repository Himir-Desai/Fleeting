import Foundation

/// Chooses what, if anything, is worth surfacing outside the app today.
///
/// Pure, so what the user is interrupted for can be reasoned about and tested without scheduling
/// a single notification.
public struct NudgeSelector: Sendable {
    private let engine: DecayEngine
    private let forgottenBelow: Double
    private let warnWithin: TimeInterval

    /// Creates a selector.
    /// - Parameters:
    ///   - engine: Used to judge how faded each thought is.
    ///   - forgottenBelow: Freshness under which a thought counts as forgotten. Defaults to 0.6.
    ///   - warnWithin: How close to expiry a thought must be to earn a warning. Defaults to 2 days.
    public init(
        engine: DecayEngine = DecayEngine(),
        forgottenBelow: Double = 0.6,
        warnWithin: TimeInterval = 2 * .day
    ) {
        self.engine = engine
        self.forgottenBelow = forgottenBelow
        self.warnWithin = warnWithin
    }

    /// The single thought most worth resurfacing.
    ///
    /// One, never a digest: the daily nudge is a reminder of something forgotten, and a list is
    /// not that. Thoughts already surfaced recently are skipped so the same note is not shown
    /// every day until it expires.
    /// - Parameters:
    ///   - thoughts: Every thought to consider.
    ///   - date: The instant to judge at.
    ///   - recentlySurfaced: Identities shown recently, which are passed over.
    /// - Returns: The most faded eligible thought, or `nil` if nothing qualifies.
    public func forgotten(
        from thoughts: [Thought],
        at date: Date,
        recentlySurfaced: Set<Thought.ID> = []
    ) -> Thought? {
        thoughts
            .filter { $0.isAwake(at: date) && !recentlySurfaced.contains($0.id) }
            .filter { engine.freshness(of: $0, at: date).value < forgottenBelow }
            .min { lhs, rhs in
                let left = engine.freshness(of: lhs, at: date).value
                let right = engine.freshness(of: rhs, at: date).value
                if left != right {
                    return left < right
                }
                return lhs.capturedAt < rhs.capturedAt
            }
    }

    /// Thoughts close enough to archiving to deserve a heads-up.
    /// - Parameters:
    ///   - thoughts: Every thought to consider.
    ///   - date: The instant to judge at.
    /// - Returns: Thoughts expiring within the warning window, soonest first.
    public func expiringSoon(from thoughts: [Thought], at date: Date) -> [Thought] {
        thoughts
            .filter { $0.isAwake(at: date) }
            .compactMap { thought -> (Thought, Date)? in
                guard let expiry = engine.expiryDate(of: thought), expiry > date else { return nil }
                return expiry.timeIntervalSince(date) <= warnWithin ? (thought, expiry) : nil
            }
            .sorted { $0.1 < $1.1 }
            .map(\.0)
    }
}
