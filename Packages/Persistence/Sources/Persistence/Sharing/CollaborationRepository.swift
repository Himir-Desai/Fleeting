import CloudKit
import Core
import CoreData
import Foundation

/// The unified repository for private thoughts, owned shares and accepted iCloud lists.
@MainActor
public final class CollaborationRepository: ThoughtRepository, ThoughtListRepository {
    public let store: CollaborationStore
    let clock: any WallClock
    var context: NSManagedObjectContext {
        store.context
    }

    /// Tests supply permissions without requiring an authenticated CloudKit account.
    var permissionOverrides: [UUID: ListSharing] = [:]

    public init(store: CollaborationStore, clock: any WallClock = SystemClock()) {
        self.store = store
        self.clock = clock
    }

    public func thoughts(in scope: ThoughtScope) async throws -> [Thought] {
        try importLegacyTasks()
        context.refreshAllObjects()
        let lists = try listRows()
        let byID = Dictionary(lists.compactMap { row -> (UUID, NSManagedObject)? in
            guard let id = row.value(forKey: "id") as? UUID else { return nil }
            return (id, row)
        }, uniquingKeysWith: { first, _ in first })
        let rows = try fetch("ThoughtEntity")
        var unique: [UUID: Thought] = [:]
        for row in rows {
            guard let id = row.value(forKey: "id") as? UUID else { continue }
            let listID = row.value(forKey: "listID") as? UUID
            let parent = row.value(forKey: "collection") as? NSManagedObject ?? listID.flatMap { byID[$0] }
            let access = access(for: row, parent: parent)
            var thought = CollaborationMapping.read(row, listID: listID, sharing: access)
            if let activity = try activity(for: thought, create: false) {
                thought = applying(
                    activity,
                    to: thought
                )
            }
            unique[id] = thought
        }
        return unique.values.filter { scope.contains($0.state) }.sorted { $0.capturedAt > $1.capturedAt }
    }

    public func add(_ thought: Thought) async throws {
        let parent = try thought.listID.flatMap { try listRow($0) }
        if let parent {
            try requireWrite(parent)
        }
        let row = NSEntityDescription.insertNewObject(forEntityName: "ThoughtEntity", into: context)
        context.assign(row, to: parent?.objectID.persistentStore ?? store.privateStore)
        row.setValue(parent, forKey: "collection")
        if let parent, sharing(parent) != nil {
            try keepPersonalProgress(thought)
            var common = commonFields(of: thought, basedOn: thought, initialShare: true)
            if case .snoozed = common.state {
                common.state = .inbox
            }
            CollaborationMapping.write(common, to: row)
        } else {
            CollaborationMapping.write(thought, to: row)
        }
        try save()
    }

    public func update(_ thought: Thought) async throws {
        guard let row = try thoughtRow(thought.id) else { throw PersistenceError.thoughtNotFound(thought.id) }
        let oldListID = row.value(forKey: "listID") as? UUID
        let linked = row.value(forKey: "collection") as? NSManagedObject
        let resolved = try oldListID.flatMap { try listRow($0) }
        let parent = linked ?? resolved
        let access = access(for: row, parent: parent)
        if let access {
            guard thought.listID == oldListID else { throw ListSharingError.moveSharedThought }
            let old = CollaborationMapping.read(row, listID: oldListID, sharing: nil)
            let common = commonFields(of: thought, basedOn: old)
            if common != old {
                guard access.canEdit else { throw ListSharingError.readOnly }
                try requireWrite(row)
                CollaborationMapping.write(common, to: row)
            }
            if let activity = try activity(for: thought, create: true) {
                writeActivity(thought, to: activity)
            }
        } else {
            try requireWrite(row)
            let target = try thought.listID.flatMap { try listRow($0) }
            if let target, sharing(target) != nil {
                throw ListSharingError.moveSharedThought
            }
            row.setValue(target, forKey: "collection")
            CollaborationMapping.write(thought, to: row)
            if let existing = try activity(for: thought, create: false) {
                writeActivity(thought, to: existing)
            }
        }
        try save()
    }

    public func delete(id: UUID) async throws {
        let rows = try fetch("ThoughtEntity", predicate: NSPredicate(format: "id == %@", id as NSUUID))
        guard !rows.isEmpty else { throw PersistenceError.thoughtNotFound(id) }
        for row in rows {
            try requireWrite(row); context.delete(row)
        }
        for row in try fetch(
            "MemberActivityEntity",
            predicate: NSPredicate(format: "thoughtID == %@", id as NSUUID),
            privateOnly: true
        ) {
            context.delete(row)
        }
        try save()
    }

    private func importLegacyTasks() throws {
        let rows = try fetch("DailyTodoEntity")
        guard !rows.isEmpty else { return }
        for row in rows {
            let data = row.value(forKey: "payload") as? Data ?? Data()
            let task = try JSONDecoder().decode(DailyTodo.self, from: data)
            if try thoughtRow(task.id) == nil {
                let imported = NSEntityDescription.insertNewObject(
                    forEntityName: "ThoughtEntity",
                    into: context
                )
                context.assign(imported, to: store.privateStore)
                CollaborationMapping.write(ThoughtListTaskRepository.thought(task), to: imported)
            }
            context.delete(row)
        }
        try save()
    }
}
