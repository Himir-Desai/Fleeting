import Foundation

/// The decay rate for each kind of thought.
///
/// Per ADR-0005 the kind of a thought changes exactly two things, and this is one of them: a todo
/// ignored for a fortnight is dead, whereas a business idea deserves months.
public struct DecayProfiles: Equatable, Sendable, Codable {
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

    /// A copy with one kind's lifetime replaced, keeping that kind's grace period.
    ///
    /// Grace is not exposed as a setting: it exists so a new capture does not appear to start
    /// dying immediately, which is a detail of how decay should feel rather than a preference.
    /// It is clamped to the new lifetime, so shortening a lifetime past its grace is safe.
    /// - Parameters:
    ///   - lifetime: The new total lifetime, in seconds.
    ///   - kind: The kind to change.
    /// - Returns: Updated profiles.
    public func setting(lifetime: TimeInterval, for kind: ThoughtKind) -> DecayProfiles {
        var updated = policies
        updated[kind] = FreshnessPolicy(grace: policy(for: kind).grace, lifetime: lifetime)
        return DecayProfiles(policies: updated, fallback: fallback)
    }

    /// Whether these are the rates the app ships with.
    public var isStandard: Bool {
        self == .standard
    }
}

// MARK: - Codable

/// Encoded as a kind-keyed dictionary of policies.
///
/// Written by hand because a dictionary keyed by an enum encodes as an unkeyed array by default,
/// which would make the stored rates unreadable by eye and brittle if a kind were ever added.
public extension DecayProfiles {
    private enum CodingKeys: String, CodingKey {
        case policies
        case fallback
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let raw = try container.decode([String: FreshnessPolicy].self, forKey: .policies)
        var decoded: [ThoughtKind: FreshnessPolicy] = [:]
        for (key, value) in raw {
            guard let kind = ThoughtKind(rawValue: key) else { continue }
            decoded[kind] = value
        }
        policies = decoded
        fallback = try container.decode(FreshnessPolicy.self, forKey: .fallback)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let raw = Dictionary(uniqueKeysWithValues: policies.map { ($0.key.rawValue, $0.value) })
        try container.encode(raw, forKey: .policies)
        try container.encode(fallback, forKey: .fallback)
    }
}
