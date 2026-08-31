import Foundation

/// What the user has asked to sort their thoughts.
///
/// A real choice rather than a report: sorting on-device costs battery and needs a capable
/// device, and some people would simply rather the app be predictable. Both answers are valid,
/// so the app asks instead of deciding (ADR-0030).
public enum SortingPreference: String, CaseIterable, Identifiable, Codable, Sendable {
    /// Use the on-device model when the device has one, and rules when it does not.
    case automatic

    /// Always use the deterministic rules, even where a model is available.
    case rulesOnly

    public var id: String {
        rawValue
    }

    /// The choice's name, as shown on its chip.
    public var label: String {
        switch self {
        case .automatic: "Automatic"
        case .rulesOnly: "Rules only"
        }
    }

    /// What choosing this actually means for the user, in one sentence.
    public var explanation: String {
        switch self {
        case .automatic:
            """
            Uses this iPhone's language model when it can, and simple rules when it cannot. \
            Nothing leaves the device either way.
            """
        case .rulesOnly:
            """
            Sorts by keywords alone. Faster and completely predictable, but it will miss things \
            a model would catch.
            """
        }
    }
}

/// Reads and writes how the user wants thoughts sorted.
public protocol SortingPreferenceStoring: Sendable {
    /// The stored choice, or ``SortingPreference/automatic`` if none has been made.
    func load() -> SortingPreference

    /// Saves a choice.
    /// - Parameter preference: What to store.
    func save(_ preference: SortingPreference)
}
