import Foundation

/// Computes how fresh a thought is and when it should be archived.
///
/// Pure and clock-free: every method takes the instant to evaluate against, so decay is tested by
/// passing dates rather than by waiting.
public struct DecayEngine: Sendable {
    /// The rates this engine applies.
    public let policy: FreshnessPolicy

    /// Creates an engine.
    /// - Parameter policy: How fast thoughts decay. Defaults to ``FreshnessPolicy/standard``.
    public init(policy: FreshnessPolicy = .standard) {
        self.policy = policy
    }

    /// How fresh a thought is at a given moment.
    ///
    /// Thoughts that have left the live states no longer decay and report as expired.
    /// - Parameters:
    ///   - thought: The thought to evaluate.
    ///   - date: The instant to evaluate at.
    /// - Returns: Freshness within 0...1.
    public func freshness(of thought: Thought, at date: Date) -> Freshness {
        guard thought.state.isLive else { return .expired }
        guard policy.decayWindow > 0 else {
            return date.timeIntervalSince(referenceDate(for: thought)) >= policy.lifetime
                ? .expired : .full
        }

        let elapsed = date.timeIntervalSince(referenceDate(for: thought))
        guard elapsed > policy.grace else { return .full }

        return Freshness(1 - (elapsed - policy.grace) / policy.decayWindow)
    }

    /// When a thought will expire if nothing else happens to it.
    /// - Parameter thought: The thought to evaluate.
    /// - Returns: The expiry instant, or `nil` for thoughts that no longer decay.
    public func expiryDate(of thought: Thought) -> Date? {
        guard thought.state.isLive else { return nil }
        return referenceDate(for: thought).addingTimeInterval(policy.lifetime)
    }

    /// Whether a thought has run out of freshness and should be moved to the archive.
    /// - Parameters:
    ///   - thought: The thought to evaluate.
    ///   - date: The instant to evaluate at.
    /// - Returns: `true` only for live thoughts whose freshness has reached zero.
    public func shouldArchive(_ thought: Thought, at date: Date) -> Bool {
        thought.state.isLive && freshness(of: thought, at: date).hasExpired
    }

    /// The instant decay is measured from.
    ///
    /// Normally the last deliberate action. A snoozed thought is held at full freshness until its
    /// snooze ends, so setting something aside genuinely buys time rather than merely hiding it.
    /// - Parameter thought: The thought to evaluate.
    /// - Returns: The instant from which elapsed time is counted.
    private func referenceDate(for thought: Thought) -> Date {
        switch thought.state {
        case let .snoozed(until): max(thought.lastActedAt, until)
        default: thought.lastActedAt
        }
    }
}
