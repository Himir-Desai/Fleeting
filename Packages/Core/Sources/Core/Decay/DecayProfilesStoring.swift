import Foundation

/// Reads and writes how long each kind of thought lasts.
///
/// Lifetimes are the app's central rule, so they are the app's central setting: a person who
/// thinks a to-do deserves a month rather than a fortnight is not wrong, they just work
/// differently (ADR-0031).
public protocol DecayProfilesStoring: Sendable {
    /// The stored profiles, or ``DecayProfiles/standard`` if none have been saved.
    func load() -> DecayProfiles

    /// Saves profiles.
    /// - Parameter profiles: What to store.
    func save(_ profiles: DecayProfiles)
}
