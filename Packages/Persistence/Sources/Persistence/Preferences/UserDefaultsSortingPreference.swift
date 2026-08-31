import Core
import Foundation

/// Stores how the user wants thoughts sorted, in `UserDefaults`.
public struct UserDefaultsSortingPreference: SortingPreferenceStoring, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "sorting.preference"

    /// Creates the store.
    /// - Parameter defaults: Where to read and write. Defaults to the standard suite.
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> SortingPreference {
        guard let raw = defaults.string(forKey: key),
              let preference = SortingPreference(rawValue: raw)
        else {
            return .automatic
        }
        return preference
    }

    public func save(_ preference: SortingPreference) {
        defaults.set(preference.rawValue, forKey: key)
    }
}
