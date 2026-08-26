import Foundation

/// Reports whether thoughts are reaching iCloud.
///
/// Lives in `Core` so the settings screen can show sync state without importing `Persistence`.
public protocol SyncReporting: Sendable {
    /// The current state of syncing.
    var status: SyncStatus { get async }
}

/// A reporter that always says the store is local. Used by previews, tests, and any build that
/// never attaches iCloud.
public struct LocalOnlySync: SyncReporting {
    private let reason: SyncUnavailableReason

    /// Creates a reporter fixed to one reason.
    /// - Parameter reason: Why the store is not syncing.
    public init(reason: SyncUnavailableReason = .notAttached) {
        self.reason = reason
    }

    public var status: SyncStatus {
        get async { .localOnly(reason) }
    }
}
