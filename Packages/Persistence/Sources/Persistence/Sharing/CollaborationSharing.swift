import CloudKit
import Core
import CoreData
import Foundation

/// Values needed by Apple's system collaboration UI, kept out of the domain layer.
@MainActor
public struct CollaborationShare {
    public let share: CKShare
    public let container: CKContainer
    public let listID: UUID
}

public extension CollaborationRepository {
    /// Creates or opens the native share for exactly one list graph.
    func prepareShare(listID: UUID) async throws -> CollaborationShare {
        guard store.cloudEnabled else { throw ListSharingError.unavailable }
        guard listID != ThoughtList.planID else { throw ListSharingError.protectedList }
        let cloud = CKContainer(identifier: CollaborationStore.cloudContainerIdentifier)
        guard try await cloud.accountStatus() == .available else { throw ListSharingError.signInRequired }
        guard let list = try listRow(listID) else { throw ThoughtListError.emptyName }
        if let existing = try store.container.fetchShares(matching: [list.objectID])[list.objectID] {
            return CollaborationShare(share: existing, container: cloud, listID: listID)
        }
        try requireWrite(list)
        try prepareListGraph(list, listID: listID)
        return try await withCheckedThrowingContinuation { continuation in
            let request = ShareRequest(continuation)
            let title = list.value(forKey: "name") as? String ?? "Shared list"
            store.container.share([list], to: nil) { _, share, container, error in
                Task { @MainActor in
                    if let error {
                        request.finish(.failure(error)); return
                    }
                    guard let share,
                          let container
                    else { request.finish(.failure(ListSharingError.unavailable)); return }
                    share[CKShare.SystemFieldKey.title] = title as CKRecordValue
                    share.publicPermission = .none
                    self.store.container.persistUpdatedShare(share, in: self.store.privateStore) { _, error in
                        Task { @MainActor in
                            if let error {
                                request.finish(.failure(error)); return
                            }
                            do {
                                try self.listRow(listID)?.setValue(true, forKey: "sharingEnabled")
                                try self.save()
                                request.finish(.success(CollaborationShare(
                                    share: share,
                                    container: container,
                                    listID: listID
                                )))
                            } catch { request.finish(.failure(error)) }
                        }
                    }
                }
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(30))
                request.finish(.failure(ListSharingError.timedOut))
            }
        }
    }

    /// Links only this list's thoughts and separates the owner's private activity before sharing.
    internal func prepareListGraph(_ list: NSManagedObject, listID: UUID) throws {
        let children = list.value(forKey: "thoughts") as? Set<NSManagedObject> ?? []
        for row in children where row.value(forKey: "listID") as? UUID != listID {
            row.setValue(nil, forKey: "collection")
        }
        let thoughts = try fetch(
            "ThoughtEntity",
            predicate: NSPredicate(format: "listID == %@", listID as NSUUID)
        )
        for row in thoughts {
            var thought = CollaborationMapping.read(row, listID: listID, sharing: nil)
            if let existing = try activity(for: thought, create: false) {
                thought = applying(existing, to: thought)
            }
            try keepPersonalProgress(thought)
            var shared = commonFields(of: thought, basedOn: thought, initialShare: true)
            if case .snoozed = shared.state {
                shared.state = .inbox
            }
            CollaborationMapping.write(shared, to: row)
            row.setValue(list, forKey: "collection")
        }
        try save()
    }

    /// Accepts a system-delivered invitation into the native shared database store.
    func acceptShare(_ metadata: CKShare.Metadata) async throws {
        guard store.cloudEnabled else { throw ListSharingError.unavailable }
        guard metadata.containerIdentifier == CollaborationStore.cloudContainerIdentifier
        else { throw ListSharingError.invalidInvitation }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            let request = ShareRequest(continuation)
            store.container.acceptShareInvitations(from: [metadata], into: store.sharedStore) { _, error in
                Task { @MainActor in
                    request.finish(error.map { .failure($0) } ?? .success(()))
                }
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(30))
                request.finish(.failure(ListSharingError.timedOut))
            }
        }
    }

    /// Resolves the list for an accepted invitation after its shared zone has imported.
    func acceptedListID(for shareID: CKRecord.ID) throws -> UUID? {
        guard store.cloudEnabled else { return nil }
        store.context.refreshAllObjects()
        let rows = try listRows().filter { $0.objectID.persistentStore == store.sharedStore }
        let shares = try store.container.fetchShares(matching: rows.map(\.objectID))
        return rows.first { shares[$0.objectID]?.recordID == shareID }?.value(forKey: "id") as? UUID
    }

    /// Refreshes the marker after native participant or permission management.
    func sharingDidChange(listID: UUID, stopped: Bool) throws {
        store.context.refreshAllObjects()
        guard let list = try listRow(listID) else { return }
        if list.objectID.persistentStore == store.privateStore {
            list.setValue(!stopped, forKey: "sharingEnabled")
            try save()
        }
    }
}

@MainActor
private final class ShareRequest<Value: Sendable> {
    private var continuation: CheckedContinuation<Value, any Error>?
    init(_ continuation: CheckedContinuation<Value, any Error>) {
        self.continuation = continuation
    }

    func finish(_ result: Result<Value, any Error>) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
    }
}
