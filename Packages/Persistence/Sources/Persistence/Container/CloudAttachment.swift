import Core
import Foundation

/// Whether the store that opened is backed by iCloud.
public enum CloudAttachment: Equatable, Sendable {
    /// The store opened against the private CloudKit database.
    case attached
    /// The store opened on this device only, for the given reason.
    case unavailable(SyncUnavailableReason)
}
