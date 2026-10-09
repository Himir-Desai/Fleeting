import Core
import CoreData
import Foundation
@testable import Persistence
import SwiftData
import Testing

@MainActor
@Suite("Core Data collaboration foundation")
struct CollaborationStoreTests {
    @Test("Core Data opens the exact SwiftData store preserving identities, content and list metadata")
    func compatibleStore() throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "Fleeting.store")
        let id = UUID(), listID = UUID()
        try autoreleasepool {
            let original = try ModelContainerFactory.open(cloudKitDatabase: .none, url: url)
            let context = ModelContext(original)
            let thought = ThoughtEntity(Thought(
                id: id,
                body: "Keep these exact words",
                capturedAt: .distantPast,
                listID: listID
            ))
            context.insert(thought)
            context.insert(ThoughtSchemaV8.ThoughtListEntity(
                id: listID,
                name: "Work",
                listDescription: "Projects",
                defaultKindRaw: "todo"
            ))
            try context.save()
        }
        let store = try CollaborationStore(privateURL: url)
        let rows = try store.context.fetch(NSFetchRequest<NSManagedObject>(entityName: "ThoughtEntity"))
        #expect(rows.count == 1)
        #expect(rows.first?.value(forKey: "id") as? UUID == id)
        #expect(rows.first?.value(forKey: "body") as? String == "Keep these exact words")
        #expect(rows.first?.value(forKey: "listID") as? UUID == listID)
        let lists = try store.context.fetch(NSFetchRequest<NSManagedObject>(entityName: "ThoughtListEntity"))
        #expect(lists.first?.value(forKey: "listDescription") as? String == "Projects")
        #expect(lists.first?.value(forKey: "defaultKindRaw") as? String == "todo")
    }
}

extension CollaborationStoreTests {
    @Test("a share graph contains only its list's thoughts and never personal activity or Plan")
    func graphIsolation() async throws {
        let store = try CollaborationStore(inMemory: true)
        let repository = CollaborationRepository(store: store)
        let list = try await repository.createList(named: "Together")
        let other = try await repository.createList(named: "Private")
        let time = Date(timeIntervalSince1970: 1_700_000_000)
        var habit = Thought(body: "Read", capturedAt: time, kind: .habit, listID: list.id)
        habit.markHabitKept(at: time.addingTimeInterval(7200))
        habit.snooze(until: time.addingTimeInterval(86400), at: time.addingTimeInterval(7200))
        let privateThought = Thought(body: "Personal", capturedAt: time, listID: other.id)
        let plan = Thought(body: "Plan", capturedAt: time, kind: .todo, listID: ThoughtList.planID)
        let archived = Thought(body: "History", capturedAt: time, state: .archived(at: time), listID: list.id)
        for thought in [habit, privateThought, plan, archived] {
            try await repository.add(thought)
        }
        let root = try #require(try repository.listRow(list.id))
        // Older app versions wrote membership without a relationship; repair stale graph edges.
        let privateRow = try #require(try repository.thoughtRow(privateThought.id))
        privateRow.setValue(root, forKey: "collection")
        try repository.save()
        try repository.prepareListGraph(root, listID: list.id)
        try repository.prepareListGraph(root, listID: list.id)
        let children = root.value(forKey: "thoughts") as? Set<NSManagedObject> ?? []
        #expect(Set(children.compactMap { $0.value(forKey: "id") as? UUID }) == [habit.id, archived.id])
        #expect(privateRow.value(forKey: "collection") == nil)
        #expect(try repository.thoughtRow(plan.id)?.value(forKey: "collection") == nil)
        let common = try #require(try repository.thoughtRow(habit.id))
        #expect(common.value(forKey: "streakCode") == nil)
        #expect(common.value(forKey: "stateCode") as? String == "inbox")
        #expect(common.value(forKey: "lastActedAt") as? Date == time)
        repository.permissionOverrides[list.id] = ListSharing(role: .owner)
        let restored = try #require(try await repository.all().first { $0.id == habit.id })
        #expect(restored.streak == habit.streak)
        #expect(restored.state == habit.state)
        #expect(restored.snoozeCount == habit.snoozeCount)
        #expect(restored.lastActedAt == habit.lastActedAt)
        let activity = try repository.fetch("MemberActivityEntity", privateOnly: true)
        #expect(activity.allSatisfy { $0.objectID.persistentStore == store.privateStore })
        let hasNoSharedRelationships = activity.allSatisfy(\.entity.relationshipsByName.isEmpty)
        #expect(hasNoSharedRelationships)
        await #expect(throws: ListSharingError.unavailable) {
            try await repository.prepareShare(listID: list.id)
        }
        #expect(try await repository.all().count == 4)
    }

    @Test("shared content and personal progress survive a durable offline reopen")
    func offlineReopen() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "Fleeting.store")
        let time = Date(timeIntervalSince1970: 1_700_000_000)
        var expected: Thought?
        try autoreleasepool {
            let store = try CollaborationStore(privateURL: url)
            let repository = CollaborationRepository(store: store)
            let list = NSEntityDescription.insertNewObject(
                forEntityName: "ThoughtListEntity",
                into: store.context
            )
            store.context.assign(list, to: store.sharedStore)
            let listID = UUID()
            list.setValue(listID, forKey: "id"); list.setValue("Reading", forKey: "name")
            let row = NSEntityDescription.insertNewObject(forEntityName: "ThoughtEntity", into: store.context)
            store.context.assign(row, to: store.sharedStore)
            var thought = Thought(body: "Together", capturedAt: time, kind: .habit, listID: listID)
            CollaborationMapping.write(thought, to: row)
            row.setValue(list, forKey: "collection")
            thought.markHabitKept(at: time)
            thought.snooze(until: time.addingTimeInterval(86400), at: time)
            try repository.keepPersonalProgress(thought)
            try repository.save()
            expected = thought
        }
        let store = try CollaborationStore(privateURL: url)
        let repository = CollaborationRepository(store: store)
        let read = try #require(try await repository.all().first)
        #expect(read.body == expected?.body)
        #expect(read.state == expected?.state)
        #expect(read.streak == expected?.streak)
        #expect(read.sharing?.role == .viewer)
        #expect(!read.canEditContent)
        #expect(try await repository.lists().first { $0.id == read.listID }?.sharing?.role == .viewer)
        await #expect(throws: ListSharingError.readOnly) { try await repository.delete(id: read.id) }
    }

    @Test("private CRUD, list metadata, lifecycle and legacy checklist use the original schema")
    func privateLifecycle() async throws {
        let store = try CollaborationStore(inMemory: true)
        let repository = CollaborationRepository(store: store)
        let list = try await repository.createList(named: "Work", description: "Projects", defaultKind: .todo)
        let time = Date(timeIntervalSince1970: 1_700_000_000)
        var thought = Thought(body: "Draft", capturedAt: time, listID: list.id)
        try await repository.add(thought)
        #expect(try await repository.all() == [thought])
        thought.archive(at: time)
        try await repository.update(thought)
        #expect(try await repository.thoughts(in: .archived) == [thought])
        #expect(try await repository.lists().contains(list))
        try await repository.deleteList(id: list.id)
        #expect(try await repository.all().first?.listID == nil)
        #expect(try await repository.all().first?.body == "Draft")
        try await repository.delete(id: thought.id)
        #expect(try await repository.all().isEmpty)
    }

    @Test("view-only shared lists reject content mutations but preserve private habit progress and hiding")
    func readOnlyAndPersonalProgress() async throws {
        let store = try CollaborationStore(inMemory: true)
        let repository = CollaborationRepository(store: store)
        let list = try await repository.createList(named: "Together")
        let time = Date(timeIntervalSince1970: 1_700_000_000)
        let thought = Thought(body: "Read", capturedAt: time, kind: .habit, listID: list.id)
        try await repository.add(thought)
        repository.permissionOverrides[list.id] = ListSharing(role: .viewer)
        var read = try #require(try await repository.all().first)
        #expect(!read.canEditContent)
        #expect(DecayEngine().expiryDate(of: read) == nil)
        #expect(!DecayEngine().shouldArchive(read, at: time.addingTimeInterval(365 * 86400)))
        read.markHabitKept(at: time)
        try await repository.update(read)
        let marked = try #require(try await repository.all().first)
        #expect(marked.streak?.count == 1)
        let common = try #require(try repository.thoughtRow(thought.id))
        #expect(common.value(forKey: "streakCode") == nil)
        #expect(try repository.fetch("MemberActivityEntity", privateOnly: true).count == 1)
        var snoozed = marked
        snoozed.snooze(until: time.addingTimeInterval(7 * 86400), at: time)
        try await repository.update(snoozed)
        #expect(try await repository.all().first?.state == snoozed.state)
        #expect(common.value(forKey: "stateCode") as? String == "inbox")
        var revised = snoozed
        revised.revise(body: "Changed by viewer", at: time)
        await #expect(throws: ListSharingError.readOnly) { try await repository.update(revised) }
        await #expect(throws: ListSharingError.readOnly) { try await repository.delete(id: thought.id) }
        await #expect(throws: ListSharingError.readOnly) {
            try await repository.add(Thought(body: "No", capturedAt: time, listID: list.id))
        }
        #expect(try await repository.all().first?.body == thought.body)
    }

    @Test("shared todos complete for everyone; shared lists require stopping sharing before deletion")
    func sharedTasks() async throws {
        let store = try CollaborationStore(inMemory: true)
        let repository = CollaborationRepository(store: store)
        let list = try await repository.createList(named: "Tasks")
        let time = Date(timeIntervalSince1970: 1_700_000_000)
        var thought = Thought(body: "Buy food", capturedAt: time, kind: .todo, listID: list.id)
        try await repository.add(thought)
        repository.permissionOverrides[list.id] = ListSharing(role: .editor)
        thought.complete(at: time)
        try await repository.update(thought)
        let common = try #require(try repository.thoughtRow(thought.id))
        #expect((common.value(forKey: "stateCode") as? String)?.hasPrefix("done") == true)
        #expect(try await repository.all().first?.state == .done(at: time))
        await #expect(throws: ListSharingError.stopSharingFirst) {
            try await repository.deleteList(id: list.id)
        }
        var moved = thought
        moved.listID = nil
        await #expect(throws: ListSharingError.moveSharedThought) { try await repository.update(moved) }
    }
}
