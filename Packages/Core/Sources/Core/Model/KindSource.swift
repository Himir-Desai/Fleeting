import Foundation

/// Where a thought's kind came from.
///
/// Distinguishing a guess from a human decision is what lets classification re-run freely without
/// ever overwriting a correction.
public enum KindSource: String, CaseIterable, Codable, Sendable {
    /// Nothing has classified the thought yet.
    case unclassified
    /// A model or a heuristic guessed the kind.
    case inferred
    /// A person set the kind. Never overwritten by classification.
    case confirmed
}
