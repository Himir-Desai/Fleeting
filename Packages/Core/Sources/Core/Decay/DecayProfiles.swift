import Foundation

/// The decay rate for each kind of thought.
///
/// Per ADR-0005 the kind of a thought changes exactly two things, and this is one of them: a todo
/// ignored for a fortnight is dead, whereas a business idea deserves months.
public struct DecayProfiles: Equatable, Sendable {
    private let policies: [ThoughtKind: FreshnessPolicy]
    private let fallback: FreshnessPolicy

    /// Creates a set of profiles.
    /// - Parameters:
    ///   - policies: A policy per kind.
    ///   - fallback: Used for any kind the dictionary omits.
    public init(policies: [ThoughtKind: FreshnessPolicy], fallback: FreshnessPolicy) {
        self.policies = policies
        self.fallback = fallback
    }

    /// The rates the app ships with.
    ///
    /// Unsorted decays on the slower end on purpose: the app must not punish a thought for the
    /// classifier not having run yet.
    public static let standard = DecayProfiles(
        policies: [
            .unsorted: FreshnessPolicy(grace: 2 * .day, lifetime: 30 * .day),
            .idea: FreshnessPolicy(grace: 7 * .day, lifetime: 90 * .day),
            .todo: FreshnessPolicy(grace: 1 * .day, lifetime: 14 * .day),
            .habit: FreshnessPolicy(grace: 1 * .day, lifetime: 7 * .day)
        ],
        fallback: FreshnessPolicy(grace: 2 * .day, lifetime: 30 * .day)
    )

    /// The policy governing a kind of thought.
    /// - Parameter kind: The kind to look up.
    /// - Returns: That kind's policy, or the fallback if none is defined.
    public func policy(for kind: ThoughtKind) -> FreshnessPolicy {
        policies[kind] ?? fallback
    }
}
