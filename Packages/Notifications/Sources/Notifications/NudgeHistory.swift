import Core
import Foundation

/// Remembers which thoughts have been surfaced recently.
///
/// Without this the daily nudge would show the most faded thought every day until it expired,
/// which is nagging rather than reminding.
public protocol NudgeHistoryStoring: Sendable {
    /// Identities surfaced recently enough to skip.
    func recentlySurfaced() -> Set<Thought.ID>

    /// Records that a thought has been surfaced.
    /// - Parameter id: The thought that was shown.
    func recordSurfaced(_ id: Thought.ID)
}

/// A history kept in `UserDefaults`, remembering the last few thoughts shown.
///
/// Marked `@unchecked Sendable` because `UserDefaults` is documented as thread-safe but is not
/// annotated as `Sendable`; the struct holds nothing else mutable.
public struct UserDefaultsNudgeHistory: NudgeHistoryStoring, @unchecked Sendable {
    private static let key = "fleeting.nudge.recentlySurfaced"
    private let limit: Int
    private let defaults: UserDefaults

    /// Creates a history.
    /// - Parameters:
    ///   - defaults: Where to store it.
    ///   - limit: How many recent identities to remember. Defaults to five.
    public init(defaults: UserDefaults = .standard, limit: Int = 5) {
        self.defaults = defaults
        self.limit = limit
    }

    public func recentlySurfaced() -> Set<Thought.ID> {
        let stored = defaults.stringArray(forKey: Self.key) ?? []
        return Set(stored.compactMap(UUID.init(uuidString:)))
    }

    public func recordSurfaced(_ id: Thought.ID) {
        var stored = defaults.stringArray(forKey: Self.key) ?? []
        stored.removeAll { $0 == id.uuidString }
        stored.insert(id.uuidString, at: 0)
        defaults.set(Array(stored.prefix(limit)), forKey: Self.key)
    }
}
