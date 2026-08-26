import Foundation

/// How fast thoughts lose freshness.
///
/// Decay is linear rather than exponential so that "expires in four days" is a statement the app
/// can actually make. A grace period holds new captures at full freshness, so the list does not
/// appear to start dying the moment something is written down.
public struct FreshnessPolicy: Equatable, Sendable {
    /// How long a thought stays at full freshness before decay begins.
    public let grace: TimeInterval

    /// How long a thought lasts, measured from its last deliberate action, before it expires.
    public let lifetime: TimeInterval

    /// Creates a policy.
    /// - Parameters:
    ///   - grace: Time at full freshness before decay starts. Clamped to at most `lifetime`.
    ///   - lifetime: Total time from last action to expiry.
    public init(grace: TimeInterval, lifetime: TimeInterval) {
        self.lifetime = max(lifetime, 0)
        self.grace = min(max(grace, 0), self.lifetime)
    }

    /// The span over which freshness actually falls from 1 to 0.
    var decayWindow: TimeInterval {
        lifetime - grace
    }
}

public extension TimeInterval {
    /// One day, in seconds. Calendar-agnostic on purpose: decay is a duration, not a date.
    static let day: TimeInterval = 86400
}
