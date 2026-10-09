import CloudKit
import Core
import CoreData
import Foundation

/// Store access and CloudKit permission checks shared by collaboration operations.
extension CollaborationRepository {
    func fetch(
        _ name: String,
        predicate: NSPredicate? = nil,
        privateOnly: Bool = false
    ) throws -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: name)
        request.predicate = predicate
        if privateOnly {
            request.affectedStores = [store.privateStore]
        }
        return try context.fetch(request)
    }

    func listRows() throws -> [NSManagedObject] {
        try fetch("ThoughtListEntity")
    }

    func listRow(_ id: UUID) throws -> NSManagedObject? {
        try fetch("ThoughtListEntity", predicate: NSPredicate(format: "id == %@", id as NSUUID)).first
    }

    func thoughtRow(_ id: UUID) throws -> NSManagedObject? {
        try fetch("ThoughtEntity", predicate: NSPredicate(format: "id == %@", id as NSUUID)).first
    }

    func sharing(_ row: NSManagedObject) -> ListSharing? {
        let id = row.value(forKey: "id") as? UUID
        if let id, let override = permissionOverrides[id] {
            return override
        }
        let isParticipant = row.objectID.persistentStore == store.sharedStore
        let share = store
            .cloudEnabled ? (try? store.container.fetchShares(matching: [row.objectID])[row.objectID]) : nil
        guard isParticipant || share != nil || row.value(forKey: "sharingEnabled") as? Bool == true
        else { return nil }
        let role: ListSharing.Role = isParticipant
            ?
            (store.cloudEnabled && store.container
                .canUpdateRecord(forManagedObjectWith: row.objectID) ? .editor : .viewer) :
            .owner
        let owner = share?.owner.userIdentity.nameComponents
            .map { PersonNameComponentsFormatter.localizedString(
                from: $0,
                style: .default
            ) }
        return ListSharing(role: role, ownerName: owner)
    }

    func requireWrite(_ row: NSManagedObject) throws {
        let parent = row.entity.name == "ThoughtListEntity" ? row : row
            .value(forKey: "collection") as? NSManagedObject
        if let parent, sharing(parent)?.canEdit == false {
            throw ListSharingError.readOnly
        }
        if row.objectID.persistentStore == store.sharedStore, !store.cloudEnabled {
            throw ListSharingError.readOnly
        }
        guard store.container.canUpdateRecord(forManagedObjectWith: row.objectID)
        else { throw ListSharingError.readOnly }
    }

    /// Protects shared-zone thoughts even when their list relationship has not imported yet.
    func access(for row: NSManagedObject, parent: NSManagedObject?) -> ListSharing? {
        if let parent, let access = sharing(parent) {
            return access
        }
        if row.objectID.persistentStore == store.sharedStore {
            let canEdit = store.cloudEnabled && store.container
                .canUpdateRecord(forManagedObjectWith: row.objectID)
            return ListSharing(role: canEdit ? .editor : .viewer)
        }
        guard store.cloudEnabled else { return nil }
        let share = try? store.container.fetchShares(matching: [row.objectID])[row.objectID]
        return share == nil ? nil : ListSharing(role: .owner)
    }

    func save() throws {
        do {
            if context.hasChanges {
                try context.save()
            }
        } catch { context.rollback(); throw error }
    }
}
