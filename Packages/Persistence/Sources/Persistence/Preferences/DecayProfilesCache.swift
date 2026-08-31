import Core
import Foundation

/// The decay rates currently in force, readable from any thread.
///
/// The engine is copied by value into the inbox, the sweeper, the review and the widgets, and it
/// consults its rates on every freshness calculation. Reading and decoding `UserDefaults` that
/// often would be wasteful, so the value is held here and only re-read when Settings changes it.
public final class DecayProfilesCache: DecayProfilesStoring, @unchecked Sendable {
    private let store: any DecayProfilesStoring
    private let lock = NSLock()
    private var cached: DecayProfiles

    /// Creates the cache, loading the stored rates once.
    /// - Parameter store: Where the rates are persisted.
    public init(store: any DecayProfilesStoring) {
        self.store = store
        cached = store.load()
    }

    /// The rates in force right now.
    public var current: DecayProfiles {
        load()
    }

    public func load() -> DecayProfiles {
        lock.lock()
        defer { lock.unlock() }
        return cached
    }

    /// Saves new rates and makes them current everywhere at once.
    /// - Parameter profiles: The rates to apply.
    public func save(_ profiles: DecayProfiles) {
        lock.lock()
        cached = profiles
        lock.unlock()
        store.save(profiles)
    }
}
