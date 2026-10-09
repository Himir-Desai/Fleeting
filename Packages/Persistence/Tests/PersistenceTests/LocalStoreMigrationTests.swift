import Core
import Foundation
@testable import Persistence
import SwiftData
import Testing

@Suite("Local account upgrade")
struct LocalStoreMigrationTests {
    @Test("upgrade preserves both stores and cannot resurrect deleted imported thoughts")
    func importOnce() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appending(path: "local.store")
        let destination = directory.appending(path: "group.store")
        let old = Thought(body: "Before joining", capturedAt: .distantPast)
        let current = Thought(body: "Already shared", capturedAt: .distantPast)
        try await seed(old, at: source)
        try await seed(current, at: destination)
        try LocalStoreMigration.migrate(from: source, to: destination)
        let container = try ModelContainerFactory.open(cloudKitDatabase: .none, url: destination)
        let repository = SwiftDataThoughtRepository(modelContainer: container)
        #expect(try await Set(repository.all().map(\.id)) == [old.id, current.id])
        #expect(FileManager.default.fileExists(atPath: source.path))
        try await repository.delete(id: old.id)
        try LocalStoreMigration.migrate(from: source, to: destination)
        #expect(try await repository.all().map(\.id) == [current.id])
    }

    @Test("local to shared-store upgrade copies list names and membership together")
    func listImport() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appending(path: "lists-local.store")
        let destination = directory.appending(path: "lists-shared.store")
        let list = ThoughtList(name: "Writing", description: "Drafts and story ideas", defaultKind: .idea)
        let thought = Thought(body: "A saved draft", capturedAt: .distantPast, listID: list.id)
        let old = try ModelContainerFactory.open(cloudKitDatabase: .none, url: source)
        let repository = SwiftDataThoughtRepository(modelContainer: old)
        try await repository.saveList(list)
        try await repository.add(thought)
        try LocalStoreMigration.migrate(from: source, to: destination)
        let shared = try ModelContainerFactory.open(cloudKitDatabase: .none, url: destination)
        let migrated = SwiftDataThoughtRepository(modelContainer: shared)
        #expect(try await migrated.lists().contains(list))
        #expect(try await migrated.all() == [thought])
        #expect(try await repository.all() == [thought])
    }

    private func seed(_ thought: Thought, at url: URL) async throws {
        let container = try ModelContainerFactory.open(cloudKitDatabase: .none, url: url)
        try await SwiftDataThoughtRepository(modelContainer: container).add(thought)
    }
}
