import CloudKit
import Core
import CoreData
import Foundation

/// List metadata and deletion with ownership and participant permissions.
public extension CollaborationRepository {
    func lists() async throws -> [ThoughtList] {
        context.refreshAllObjects()
        var unique: [UUID: ThoughtList] = [:]
        for row in try listRows() {
            guard let id = row.value(forKey: "id") as? UUID, id != ThoughtList.planID else { continue }
            unique[id] = ThoughtList(
                id: id,
                name: row.value(forKey: "name") as? String ?? "",
                description: row.value(forKey: "listDescription") as? String ?? "",
                defaultKind: ThoughtKind(rawValue: row
                    .value(forKey: "defaultKindRaw") as? String ?? "") ?? .unsorted,
                sharing: sharing(row)
            )
        }
        return [.plan] + unique.values
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func saveList(_ list: ThoughtList) async throws {
        guard !list.isBuiltIn else { throw ThoughtListError.builtInList }
        let name = list.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw ThoughtListError.emptyName }
        let existing = try listRows()
        let current = existing.first { $0.value(forKey: "id") as? UUID == list.id }
        let isShared = current.flatMap(sharing) != nil
        guard name.localizedCaseInsensitiveCompare("Plan") != .orderedSame,
              isShared || !existing.contains(where: { $0.objectID.persistentStore == store.privateStore &&
                      ($0.value(forKey: "id") as? UUID) != list.id &&
                      ($0.value(forKey: "name") as? String ?? "")
                      .localizedCaseInsensitiveCompare(name) == .orderedSame
              })
        else {
            throw ThoughtListError.duplicateName
        }
        let row: NSManagedObject
        if let current {
            try requireWrite(current); row = current
        } else {
            row = NSEntityDescription.insertNewObject(forEntityName: "ThoughtListEntity", into: context)
            context.assign(row, to: store.privateStore)
            row.setValue(list.id, forKey: "id")
        }
        row.setValue(name, forKey: "name")
        row.setValue(
            list.description.trimmingCharacters(in: .whitespacesAndNewlines),
            forKey: "listDescription"
        )
        row.setValue(list.defaultKind.rawValue, forKey: "defaultKindRaw")
        try save()
    }

    func deleteList(id: UUID) async throws {
        guard id != ThoughtList.planID else { throw ThoughtListError.builtInList }
        guard let list = try listRow(id) else { return }
        guard sharing(list) == nil else { throw ListSharingError.stopSharingFirst }
        try requireWrite(list)
        for thought in try fetch(
            "ThoughtEntity",
            predicate: NSPredicate(format: "listID == %@", id as NSUUID)
        ) {
            thought.setValue(nil, forKey: "listID"); thought.setValue(nil, forKey: "collection")
        }
        context.delete(list)
        try save()
    }
}
