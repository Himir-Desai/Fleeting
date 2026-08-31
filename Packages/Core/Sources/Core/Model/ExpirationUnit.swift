import Foundation

/// The unit a chosen lifetime is measured in, when a thought's expiry is set by hand rather than
/// left to its kind.
///
/// Lives in `Core` because both capture and the thought detail let a person express a lifetime,
/// and a duration in days, weeks or months is a domain idea rather than a presentation one.
public enum ExpirationUnit: String, CaseIterable, Identifiable, Sendable {
    case days
    case weeks
    case months

    public var id: String {
        rawValue
    }

    /// The unit's name, capitalised for a wheel or a label.
    public var label: String {
        rawValue.capitalized
    }

    /// One of this unit, in seconds. A month is treated as 30 days.
    public var seconds: TimeInterval {
        switch self {
        case .days: .day
        case .weeks: 7 * .day
        case .months: 30 * .day
        }
    }
}
