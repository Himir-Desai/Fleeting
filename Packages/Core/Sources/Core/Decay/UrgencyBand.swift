import Foundation

/// How much time a thought has left, as the list groups it.
///
/// The list's primary axis (ADR-0036). Kind answers "what is this?", which is not the question
/// someone opens the app with; urgency answers "what am I about to lose?", which is.
public enum UrgencyBand: String, CaseIterable, Sendable {
    /// Fading or expiring: the thought archives itself soon unless something happens.
    case goingSoon
    /// Settling: real time left, but not indefinitely.
    case thisMonth
    /// Fresh: nothing to decide yet.
    case plentyOfTime

    /// The band a freshness value falls in.
    ///
    /// Derived from the same thresholds the surface treatment uses, so the section a thought sits
    /// in and the way its card is drawn can never disagree.
    /// - Parameter freshness: A value within 0...1.
    /// - Returns: The band it belongs to.
    public static func band(forFreshness freshness: Double) -> UrgencyBand {
        if freshness < fadingBelow {
            return .goingSoon
        }
        if freshness < settlingBelow {
            return .thisMonth
        }
        return .plentyOfTime
    }

    /// Below this a thought is going soon. Matches the design system's fading threshold.
    public static let fadingBelow = 0.45

    /// Below this a thought is in its middle life.
    public static let settlingBelow = 0.75

    /// The section heading shown above this band's thoughts.
    public var title: String {
        switch self {
        case .goingSoon: "Going soon"
        case .thisMonth: "This month"
        case .plentyOfTime: "Plenty of time"
        }
    }
}
