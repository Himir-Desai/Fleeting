import Foundation

/// What the app can currently say about keeping thoughts in step across devices.
public enum SyncStatus: Equatable, Sendable {
    /// The store is attached to iCloud and an account is available.
    case syncing
    /// The store is attached to iCloud, but nobody is signed in on this device.
    case signedOut
    /// Thoughts live on this device only.
    case localOnly(SyncUnavailableReason)
    /// The account has not been asked yet.
    case checking

    /// Whether thoughts are currently reaching iCloud.
    public var isSyncing: Bool {
        self == .syncing
    }
}

/// Why a store is not syncing.
public enum SyncUnavailableReason: String, Equatable, Sendable, CaseIterable {
    /// This copy of the store was never attached to iCloud.
    case notAttached
    /// iCloud refused the store — usually a missing entitlement or an unsigned build.
    case refusedByCloudKit
    /// The account exists but is restricted by parental controls or a device policy.
    case accountRestricted
    /// iCloud could not be reached to find out.
    case undetermined

    /// A sentence explaining the state in the user's terms.
    public var summary: String {
        switch self {
        case .notAttached:
            "This build is not set up to sync, so thoughts stay on this device."
        case .refusedByCloudKit:
            "iCloud turned the store down, so thoughts stay on this device."
        case .accountRestricted:
            "This iCloud account is not allowed to use iCloud Drive."
        case .undetermined:
            "iCloud could not be reached just now."
        }
    }
}
