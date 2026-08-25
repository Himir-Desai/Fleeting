import Foundation

/// How alive a thought still is, from 1 (just captured or just acted on) down to 0 (expired).
public struct Freshness: Equatable, Comparable, Sendable {
    /// The freshness value, always within 0...1.
    public let value: Double

    /// Creates a freshness, clamping the given value into 0...1.
    /// - Parameter value: Raw freshness, which may fall outside the valid range.
    public init(_ value: Double) {
        self.value = min(max(value, 0), 1)
    }

    /// Fully fresh.
    public static let full = Freshness(1)

    /// Entirely decayed.
    public static let expired = Freshness(0)

    /// Whether the thought has run out of freshness and is due to be archived.
    public var hasExpired: Bool {
        value <= 0
    }

    /// The presentation band this value falls into.
    public var band: Band {
        switch value {
        case ..<0.05: .expiring
        case ..<0.35: .fading
        case ..<0.70: .settling
        default: .fresh
        }
    }

    public static func < (lhs: Freshness, rhs: Freshness) -> Bool {
        lhs.value < rhs.value
    }

    /// Coarse buckets used for presentation, so views never branch on raw numbers.
    public enum Band: String, CaseIterable, Sendable {
        /// Recently captured or acted on.
        case fresh
        /// Past its first flush, still clearly alive.
        case settling
        /// Visibly going. The point at which the list starts nudging.
        case fading
        /// About to be archived.
        case expiring
    }
}
