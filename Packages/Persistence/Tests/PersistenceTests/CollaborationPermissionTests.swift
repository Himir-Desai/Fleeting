import Core
import CoreData
import Foundation
@testable import Persistence
import Testing

extension CollaborationStoreTests {
    @Test("thoughts importing before their shared list cannot decay or bypass view-only access")
    func incompleteSharedGraph() async throws {
        let store = try CollaborationStore(inMemory: true)
        let repository = CollaborationRepository(store: store)
        let time = Date(timeIntervalSince1970: 1_700_000_000)
        let thought = Thought(body: "Arrives before its list", capturedAt: time, listID: UUID())
        let row = NSEntityDescription.insertNewObject(forEntityName: "ThoughtEntity", into: store.context)
        store.context.assign(row, to: store.sharedStore)
        CollaborationMapping.write(thought, to: row)
        try repository.save()
        let read = try #require(try await repository.all().first)
        #expect(read.sharing?.role == .viewer)
        #expect(!DecayEngine().shouldArchive(read, at: time.addingTimeInterval(4000 * 86400)))
        var revised = read
        revised.revise(body: "Not allowed", at: time)
        await #expect(throws: ListSharingError.readOnly) { try await repository.update(revised) }
        await #expect(throws: ListSharingError.readOnly) { try await repository.delete(id: thought.id) }
        #expect(try await repository.all().first?.body == thought.body)
    }

    @Test("same-account activity collisions select the most recent record with a stable tie-break")
    func personalActivityCollision() async throws {
        let store = try CollaborationStore(inMemory: true)
        let repository = CollaborationRepository(store: store)
        let list = try await repository.createList(named: "Together")
        let time = Date(timeIntervalSince1970: 1_700_000_000)
        let thought = Thought(body: "Read", capturedAt: time, kind: .habit, listID: list.id)
        try await repository.add(thought)
        repository.permissionOverrides[list.id] = ListSharing(role: .owner)
        for count in [2, 5] {
            let row = NSEntityDescription.insertNewObject(
                forEntityName: "MemberActivityEntity",
                into: store.context
            )
            store.context.assign(row, to: store.privateStore)
            row.setValue(UUID(), forKey: "id")
            row.setValue(thought.id, forKey: "thoughtID")
            row.setValue(time.addingTimeInterval(Double(count)), forKey: "updatedAt")
            row.setValue(
                StoredStreak.code(for: Streak(count: count, lastMarkedAt: time)),
                forKey: "streakCode"
            )
        }
        try repository.save()
        #expect(try await repository.all().first?.streak?.count == 5)
        var read = try #require(try await repository.all().first)
        read.undoHabitKept()
        try await repository.update(read)
        #expect(try await repository.all().first?.streak?.count == read.streak?.count)
    }

    @Test("received list names do not prevent creating personal lists and viewers cannot change metadata")
    func receivedListNamingAndPermissions() async throws {
        let store = try CollaborationStore(inMemory: true)
        let repository = CollaborationRepository(store: store)
        let id = UUID()
        let received = NSEntityDescription.insertNewObject(
            forEntityName: "ThoughtListEntity",
            into: store.context
        )
        store.context.assign(received, to: store.sharedStore)
        received.setValue(id, forKey: "id")
        received.setValue("Work", forKey: "name")
        try repository.save()
        _ = try await repository.createList(named: "Work")
        #expect(try await repository.lists().filter { $0.name == "Work" }.count == 2)
        var viewerList = try #require(try await repository.lists().first { $0.id == id })
        viewerList.description = "No permission"
        await #expect(throws: ListSharingError.readOnly) { try await repository.saveList(viewerList) }
        #expect(received.value(forKey: "listDescription") as? String == "")
    }
}
