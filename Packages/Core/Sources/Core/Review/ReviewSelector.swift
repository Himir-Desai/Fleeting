import Foundation

/// Chooses the few thoughts that genuinely need a decision this week.
///
/// Pure and capped. A review that surfaces the whole backlog is a review that gets skipped, and a
/// skipped review breaks the mechanic decay depends on (ADR-0007).
public struct ReviewSelector: Sendable {
    /// The most cards one session may contain.
    public let limit: Int

    private let engine: DecayEngine
    private let threshold: Double
    private let repeatedSnoozes: Int

    /// Creates a selector.
    /// - Parameters:
    ///   - engine: Used to judge how close each thought is to expiring.
    ///   - limit: The hard cap on session length. Defaults to seven.
    ///   - threshold: Freshness at or below which a thought needs a decision. Defaults to a half.
    ///   - repeatedSnoozes: How many snoozes make a thought worth raising regardless of freshness.
    public init(
        engine: DecayEngine = DecayEngine(),
        limit: Int = 7,
        threshold: Double = 0.5,
        repeatedSnoozes: Int = 2
    ) {
        self.engine = engine
        self.limit = max(limit, 0)
        self.threshold = threshold
        self.repeatedSnoozes = repeatedSnoozes
    }

    /// Picks the thoughts to deal in this session, most urgent first.
    ///
    /// Thoughts still inside a running snooze are left alone: setting something aside has to mean
    /// something, or snoozing is just a slower way of being nagged.
    /// - Parameters:
    ///   - thoughts: Every thought to consider. Archived and completed ones are ignored.
    ///   - date: The instant to judge urgency at.
    /// - Returns: At most ``limit`` thoughts, most urgent first.
    public func select(from thoughts: [Thought], at date: Date) -> [Thought] {
        thoughts
            .filter { isEligible($0, at: date) }
            .map { (thought: $0, urgency: urgency(of: $0, at: date)) }
            .sorted { lhs, rhs in
                if lhs.urgency != rhs.urgency {
                    return lhs.urgency > rhs.urgency
                }
                return lhs.thought.capturedAt < rhs.thought.capturedAt
            }
            .prefix(limit)
            .map(\.thought)
    }

    /// How many thoughts a session would contain, without building it.
    /// - Parameters:
    ///   - thoughts: Every thought to consider.
    ///   - date: The instant to judge urgency at.
    /// - Returns: The size of the session, capped at ``limit``.
    public func count(from thoughts: [Thought], at date: Date) -> Int {
        select(from: thoughts, at: date).count
    }

    /// Whether a thought belongs in a review at all.
    /// - Parameters:
    ///   - thought: The thought to test.
    ///   - date: The instant to judge at.
    /// - Returns: `true` if it is live, awake, and either fading or repeatedly deferred.
    private func isEligible(_ thought: Thought, at date: Date) -> Bool {
        guard thought.state.isLive, !isAsleep(thought, at: date) else { return false }
        if thought.snoozeCount >= repeatedSnoozes {
            return true
        }
        return engine.freshness(of: thought, at: date).value <= threshold
    }

    /// Whether a snooze is still running.
    /// - Parameters:
    ///   - thought: The thought to test.
    ///   - date: The instant to judge at.
    /// - Returns: `true` while the thought is deliberately set aside.
    private func isAsleep(_ thought: Thought, at date: Date) -> Bool {
        guard case let .snoozed(until) = thought.state else { return false }
        return date < until
    }

    /// How badly a thought needs a decision.
    ///
    /// Mostly how close it is to expiring, nudged up by how often it has been deferred. Repeated
    /// snoozing is capped so a single much-deferred thought cannot crowd out everything about to
    /// be lost.
    /// - Parameters:
    ///   - thought: The thought to score.
    ///   - date: The instant to judge at.
    /// - Returns: A score where higher means more urgent.
    private func urgency(of thought: Thought, at date: Date) -> Double {
        let decayed = 1 - engine.freshness(of: thought, at: date).value
        let deferred = Double(min(thought.snoozeCount, 4)) * 0.15
        return decayed + deferred
    }
}
