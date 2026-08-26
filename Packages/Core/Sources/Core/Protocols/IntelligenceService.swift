import Foundation

/// What a classifier decided a captured thought is.
public struct Classification: Equatable, Sendable {
    /// The kind the thought appears to be.
    public let kind: ThoughtKind

    /// A short generated title, or `nil` if none was produced.
    public let title: String?

    /// How sure the classifier is, within 0...1.
    public let confidence: Double

    /// Creates a classification.
    /// - Parameters:
    ///   - kind: The inferred kind.
    ///   - title: A generated title, if any.
    ///   - confidence: Certainty within 0...1.
    public init(kind: ThoughtKind, title: String?, confidence: Double) {
        self.kind = kind
        self.title = title
        self.confidence = min(max(confidence, 0), 1)
    }

    /// The result when nothing could be determined.
    public static let unknown = Classification(kind: .unsorted, title: nil, confidence: 0)
}

/// Reads captured text and says what it is.
///
/// Every capability here must have a defined behaviour when no model is available, because
/// intelligence in this app is always optional (ADR-0004).
public protocol IntelligenceService: Sendable {
    /// Which implementation is currently answering, and why.
    var availability: IntelligenceAvailability { get async }

    /// Decides what a captured thought is and proposes a short title.
    /// - Parameter text: The raw captured text. Never modified.
    /// - Returns: The classification, or ``Classification/unknown`` if nothing could be decided.
    func classify(_ text: String) async -> Classification
}

/// Which intelligence implementation is serving requests right now.
///
/// Surfaced honestly in Settings: the app never pretends a model ran when it did not.
public enum IntelligenceAvailability: Equatable, Sendable {
    /// The on-device language model is answering.
    case onDevice
    /// Deterministic heuristics are answering, for the stated reason.
    case heuristic(reason: HeuristicReason)
}

/// Why the app fell back to heuristics.
public enum HeuristicReason: String, CaseIterable, Sendable {
    /// The device or OS has no on-device model.
    case modelUnsupported
    /// Apple Intelligence is supported but switched off.
    case modelDisabled
    /// The model exists but is still downloading or warming up.
    case modelNotReady
    /// A request failed or timed out, so the app degraded rather than showing an error.
    case requestFailed
    /// This build has no on-device model available to it at all.
    case notBuiltIn

    /// A short phrase suitable for showing in Settings.
    public var summary: String {
        switch self {
        case .modelUnsupported: "This device has no on-device model."
        case .modelDisabled: "Apple Intelligence is turned off."
        case .modelNotReady: "The on-device model is still preparing."
        case .requestFailed: "The last request failed, so sorting fell back to rules."
        case .notBuiltIn: "This build sorts with rules only."
        }
    }
}
