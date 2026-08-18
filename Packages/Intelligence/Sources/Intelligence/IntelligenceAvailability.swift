import Foundation

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
    /// The user chose heuristics in Settings.
    case userPreference
}
