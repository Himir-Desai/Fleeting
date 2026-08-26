import Core
import Foundation
@testable import Persistence
import SwiftData
import Testing

@Suite("Schema migration")
struct SchemaMigrationTests {
    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    /// A directory that holds one test's store and is removed with it.
    private func withTemporaryStore(
        _ body: (URL) throws -> Void
    ) throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory.appending(path: "Fleeting.store"))
    }

    /// Writes a store in the shape the shipped Phase 6 build wrote.
    private func writeVersion1Store(at url: URL, rows: [ThoughtSchemaV1.ThoughtEntity]) throws {
        let schema = Schema(versionedSchema: ThoughtSchemaV1.self)
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, url: url)
        )
        let context = ModelContext(container)
        for row in rows {
            context.insert(row)
        }
        try context.save()
    }

    /// Opens an existing store at the current version, running the migration plan.
    private func openVersion2Store(at url: URL) throws -> [Thought] {
        let schema = Schema(versionedSchema: ThoughtSchemaV2.self)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: ThoughtMigrationPlan.self,
            configurations: ModelConfiguration(schema: schema, url: url)
        )
        let context = ModelContext(container)
        return try context.fetch(FetchDescriptor<ThoughtEntity>()).map(\.domain)
    }

    private func version1Row(
        body: String,
        stateRaw: String,
        stateDate: Date?,
        streakCount: Int = 0,
        streakLastMarkedAt: Date? = nil
    ) -> ThoughtSchemaV1.ThoughtEntity {
        ThoughtSchemaV1.ThoughtEntity(
            id: UUID(),
            body: body,
            title: nil,
            kindRaw: "idea",
            stateRaw: stateRaw,
            stateDate: stateDate,
            capturedAt: epoch,
            lastActedAt: epoch,
            kindSourceRaw: "model",
            dueAt: nil,
            streakCount: streakCount,
            streakLastMarkedAt: streakLastMarkedAt,
            sharpeningJSON: nil,
            snoozeCount: 2
        )
    }

    @Test("an archive written by the previous version is still an archive after migrating")
    func archiveSurvivesMigration() throws {
        let archivedAt = epoch.addingTimeInterval(3 * .day)
        try withTemporaryStore { url in
            try writeVersion1Store(at: url, rows: [
                version1Row(body: "learn to sail", stateRaw: "archived", stateDate: archivedAt)
            ])

            let migrated = try openVersion2Store(at: url)
            #expect(migrated.count == 1)
            #expect(migrated[0].state == .archived(at: archivedAt))
        }
    }

    @Test("every lifecycle position survives the migration")
    func everyStateSurvivesMigration() throws {
        let date = epoch.addingTimeInterval(.day)
        let expected: [String: ThoughtState] = [
            "inbox": .inbox,
            "active": .active,
            "snoozed": .snoozed(until: date),
            "archived": .archived(at: date),
            "done": .done(at: date)
        ]

        try withTemporaryStore { url in
            try writeVersion1Store(at: url, rows: expected.keys.map { raw in
                version1Row(
                    body: raw,
                    stateRaw: raw,
                    stateDate: raw == "inbox" || raw == "active" ? nil : date
                )
            })

            for thought in try openVersion2Store(at: url) {
                #expect(thought.state == expected[thought.body])
            }
        }
    }

    @Test("a habit keeps its streak across the migration")
    func streakSurvivesMigration() throws {
        let marked = epoch.addingTimeInterval(2 * .day)
        try withTemporaryStore { url in
            try writeVersion1Store(at: url, rows: [
                version1Row(
                    body: "stretch before coffee",
                    stateRaw: "inbox",
                    stateDate: nil,
                    streakCount: 6,
                    streakLastMarkedAt: marked
                )
            ])

            let migrated = try openVersion2Store(at: url)
            #expect(migrated[0].streak == Streak(count: 6, lastMarkedAt: marked))
        }
    }

    @Test("a thought that never had a streak does not gain an empty one")
    func absentStreakStaysAbsent() throws {
        try withTemporaryStore { url in
            try writeVersion1Store(at: url, rows: [
                version1Row(body: "pay the parking fine", stateRaw: "inbox", stateDate: nil)
            ])

            #expect(try openVersion2Store(at: url)[0].streak == nil)
        }
    }

    @Test("the migrated store is still writable, and reopening it does not migrate twice")
    func migratedStoreIsUsable() throws {
        let archivedAt = epoch.addingTimeInterval(.day)
        try withTemporaryStore { url in
            try writeVersion1Store(at: url, rows: [
                version1Row(body: "old thought", stateRaw: "archived", stateDate: archivedAt)
            ])

            let schema = Schema(versionedSchema: ThoughtSchemaV2.self)
            let container = try ModelContainer(
                for: schema,
                migrationPlan: ThoughtMigrationPlan.self,
                configurations: ModelConfiguration(schema: schema, url: url)
            )
            let repository = SwiftDataThoughtRepository(modelContainer: container)
            let fresh = Thought(body: "new thought", capturedAt: epoch)

            let live = try {
                let context = ModelContext(container)
                context.insert(ThoughtEntity(fresh))
                try context.save()
                return try context.fetch(
                    FetchDescriptor<ThoughtEntity>(predicate: #Predicate { $0.isLive })
                ).map(\.domain)
            }()

            #expect(live.map(\.body) == ["new thought"])
            #expect(try openVersion2Store(at: url).count == 2)
            _ = repository
        }
    }

    @Test("the columns an older build reads are kept current")
    func rollbackColumnsStayCurrent() {
        let until = epoch.addingTimeInterval(5 * .day)
        var thought = Thought(body: "call the landlord", capturedAt: epoch)
        thought.snooze(until: until, at: epoch)
        thought.markHabitKept(at: epoch)

        let row = ThoughtEntity(thought)
        #expect(row.stateRaw == "snoozed")
        #expect(row.stateDate == until)
        #expect(row.streakCount == thought.streak?.count)
        #expect(row.streakLastMarkedAt == thought.streak?.lastMarkedAt)
    }
}
