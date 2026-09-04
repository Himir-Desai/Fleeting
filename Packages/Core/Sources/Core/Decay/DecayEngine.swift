import Foundation

/// Computes how fresh a thought is and when it should be archived.
///
/// Pure and clock-free: every method takes the instant to evaluate against, so decay is tested by
/// passing dates rather than by waiting.
public struct DecayEngine: Sendable {
    private let source: @Sendable () -> DecayProfiles

    /// The rates this engine applies, one per kind of thought.
    ///
    /// Read through a closure rather than stored, because the rates are editable in Settings and
    /// this engine is copied by value into the inbox, the sweeper, the review and the widgets.
    /// A stored snapshot would leave every one of those on yesterday's rates until relaunch.
    public var profiles: DecayProfiles {
        source()
    }

    /// Creates an engine with fixed rates.
    /// - Parameter profiles: How fast each kind decays. Defaults to ``DecayProfiles/standard``.
    public init(profiles: DecayProfiles = .standard) {
        source = { profiles }
    }

    /// Creates an engine that reads its rates afresh on every use.
    /// - Parameter profiles: Consulted whenever a rate is needed. Must be cheap.
    public init(profiles: @escaping @Sendable () -> DecayProfiles) {
        source = profiles
    }

    /// The policy governing a particular thought.
    ///
    /// A capture-time lifetime override wins over the kind's rate: the whole chosen span is the
    /// decay ramp, with no grace, so "expires in two weeks" falls to zero at exactly two weeks.
    ///
    /// A habit decays over its own cadence rather than the shared habit rate. The shipped rate is
    /// a week, which is right for a daily habit and fatal for a monthly one: it would be archived
    /// three weeks before it was ever due again, so a habit could be destroyed by the app for
    /// obeying the rhythm the app itself inferred (ADR-0048).
    /// - Parameter thought: The thought to look up.
    /// - Returns: The policy for that thought's custom lifetime, cadence, or kind.
    public func policy(for thought: Thought) -> FreshnessPolicy {
        if let custom = thought.customLifetime {
            return FreshnessPolicy(grace: 0, lifetime: custom)
        }
        let base = profiles.policy(for: thought.kind)
        guard thought.kind == .habit else { return base }

        // Two whole periods, matching the streak's own grace: a habit is only past saving once
        // it has missed twice. Never shorter than the configured rate, so a daily habit keeps
        // whatever the user set in Settings.
        let overCadence = thought.cadence.grace
        guard overCadence > base.lifetime else { return base }
        return FreshnessPolicy(grace: base.grace, lifetime: overCadence)
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
        let policy = policy(for: thought)
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
        return referenceDate(for: thought).addingTimeInterval(policy(for: thought).lifetime)
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
