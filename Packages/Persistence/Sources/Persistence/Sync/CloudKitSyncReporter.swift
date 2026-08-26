import CloudKit
import Core
import Foundation

/// Reports sync state by asking CloudKit about the signed-in account.
///
/// Only asks when the store actually attached to iCloud. This is a safety requirement, not a
/// tidiness one: an unentitled process is trapped by CloudKit rather than told, so the question
/// may only be put by a build already known to hold the entitlement (ADR-0019).
public struct CloudKitSyncReporter: SyncReporting {
    private let attachment: CloudAttachment
    private let containerIdentifier: String

    /// Creates a reporter for an opened store.
    /// - Parameters:
    ///   - attachment: What happened when the store was opened.
    ///   - containerIdentifier: The CloudKit container to ask about.
    public init(
        attachment: CloudAttachment,
        containerIdentifier: String = ModelContainerFactory.cloudContainerIdentifier
    ) {
        self.attachment = attachment
        self.containerIdentifier = containerIdentifier
    }

    public var status: SyncStatus {
        get async {
            guard case .attached = attachment else {
                if case let .unavailable(reason) = attachment {
                    return .localOnly(reason)
                }
                return .localOnly(.undetermined)
            }
            return await accountStatus()
        }
    }

    /// Translates CloudKit's account status into what the user is told.
    /// - Returns: The sync state implied by the account.
    private func accountStatus() async -> SyncStatus {
        do {
            switch try await CKContainer(identifier: containerIdentifier).accountStatus() {
            case .available: return .syncing
            case .noAccount: return .signedOut
            case .restricted: return .localOnly(.accountRestricted)
            case .couldNotDetermine, .temporarilyUnavailable: return .localOnly(.undetermined)
            @unknown default: return .localOnly(.undetermined)
            }
        } catch {
            return .localOnly(.undetermined)
        }
    }
}
