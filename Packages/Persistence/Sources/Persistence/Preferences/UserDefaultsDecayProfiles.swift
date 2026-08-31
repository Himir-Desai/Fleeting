import Core
import Foundation

/// Stores the user's decay rates, in `UserDefaults`.
///
/// Small and rarely written, so JSON in defaults rather than a row in the database: the rates are
/// a preference about the app, not data the user captured.
public struct UserDefaultsDecayProfiles: DecayProfilesStoring, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "decay.profiles"

    /// Creates the store.
    /// - Parameter defaults: Where to read and write. Defaults to the standard suite.
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> DecayProfiles {
        guard let data = defaults.data(forKey: key),
              let stored = try? JSONDecoder().decode(DecayProfiles.self, from: data)
        else {
            return .standard
        }
        return stored
    }

    public func save(_ profiles: DecayProfiles) {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        defaults.set(data, forKey: key)
    }
}
