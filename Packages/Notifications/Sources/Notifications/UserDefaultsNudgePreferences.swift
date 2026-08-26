import Core
import Foundation

/// Notification preferences kept in `UserDefaults`.
///
/// Marked `@unchecked Sendable` because `UserDefaults` is documented as thread-safe but is not
/// annotated as `Sendable`; the struct holds nothing else mutable.
public struct UserDefaultsNudgePreferences: NudgePreferencesStoring, @unchecked Sendable {
    private static let key = "fleeting.nudge.preferences"
    private let defaults: UserDefaults

    /// Creates a preferences store.
    /// - Parameter defaults: Where to store them.
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The stored preferences.
    ///
    /// Unreadable data falls back to the defaults rather than throwing: notification settings are
    /// not worth failing a launch over.
    public func load() -> NudgePreferences {
        guard let data = defaults.data(forKey: Self.key),
              let stored = try? JSONDecoder().decode(NudgePreferences.self, from: data)
        else { return .standard }
        return stored
    }

    public func save(_ preferences: NudgePreferences) {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
