import Core
import CoreData
import Foundation
@testable import Persistence
import SwiftData
import Testing

/// The only suite that stands up containers for *old* schema versions.
///
/// **Run this bundle on its own**: `swift test --filter SchemaMigrationTests`. SwiftData binds an
/// entity name to one class per process, so a version 1 container — which has neither `isLive` nor
/// `stateCode` — can answer the current version's queries in any other suite sharing the process,
/// and archived thoughts silently come back live. `--no-parallel` does not help; the classes are
/// registered either way. That is why this is a separate test target, and why CI runs it as a
/// second `swift test` invocation.
///
/// Within a test, a container is opened at the version of whatever entity class the test then
/// uses: `ThoughtEntity` names the current version, so opening at an older one hands back rows
/// SwiftData cannot cast, and that failure is a trap that kills the process rather than failing
/// one case.
///
/// The suite is `.serialized` for the same reason. Its cases each stand up a container at a
/// different schema version, and swift-testing runs cases in parallel by default — so two
/// versions of the same entity name could be registered at once, which crashed the process with
/// a signal 11 on roughly one run in three. Separate stores are not enough; the registration is
/// per-process, not per-store.
@Suite("Schema migration", .serialized)
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
    ///
    /// The container is opened at the version `ThoughtEntity` actually names. Opening at an older
    /// version and fetching the current entity asks SwiftData to cast across versions, which is a
    /// trap rather than an error and takes the whole test process down with it.
    private func openCurrentStore(at url: URL) throws -> [Thought] {
        let schema = Schema(versionedSchema: ThoughtSchemaV8.self)
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

            let migrated = try openCurrentStore(at: url)
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

            for thought in try openCurrentStore(at: url) {
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

            let migrated = try openCurrentStore(at: url)
            #expect(migrated[0].streak == Streak(count: 6, lastMarkedAt: marked))
        }
    }

    @Test("a thought that never had a streak does not gain an empty one")
    func absentStreakStaysAbsent() throws {
        try withTemporaryStore { url in
            try writeVersion1Store(at: url, rows: [
                version1Row(body: "pay the parking fine", stateRaw: "inbox", stateDate: nil)
            ])

            #expect(try openCurrentStore(at: url)[0].streak == nil)
        }
    }

    @Test("the migrated store is still writable, and reopening it does not migrate twice")
    func migratedStoreIsUsable() throws {
        let archivedAt = epoch.addingTimeInterval(.day)
        try withTemporaryStore { url in
            try writeVersion1Store(at: url, rows: [
                version1Row(body: "old thought", stateRaw: "archived", stateDate: archivedAt)
            ])

            // At the current version, because `ThoughtEntity` is the current entity: opening at
            // an older one and inserting asks SwiftData to cast across versions, which traps.
            let schema = Schema(versionedSchema: ThoughtSchemaV8.self)
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
            #expect(try openCurrentStore(at: url).count == 2)
            _ = repository
        }
    }

    @Test("a habit stored before cadences existed migrates to the default rather than to nothing")
    func cadenceDefaultsAfterMigration() throws {
        try withTemporaryStore { url in
            try writeVersion1Store(at: url, rows: [
                version1Row(
                    body: "stretch before coffee",
                    stateRaw: "inbox",
                    stateDate: nil,
                    streakCount: 3,
                    streakLastMarkedAt: epoch
                )
            ])

            // Every habit written before version 4 was implicitly daily, so that is what it has
            // to still be: a migration that changed how often an existing habit is asked for
            // would silently rewrite the user's routine (ADR-0048).
            #expect(try openCurrentStore(at: url)[0].cadence == .daily)
        }
    }

    @Test("a chosen cadence survives a write and a read")
    func cadenceRoundTrips() {
        var thought = Thought(body: "call mum on sundays", capturedAt: epoch, kind: .habit)
        thought.setCadence(.weekly)

        #expect(ThoughtEntity(thought).domain.cadence == .weekly)
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

extension SchemaMigrationTests {
    @MainActor
    @Test(
        "V7 upgrades to native collaboration without replacing store identity, text, lifecycle or list metadata"
    )
    func version7CollaborationMigration() throws {
        try withTemporaryStore { url in
            let thoughtID = UUID(), listID = UUID()
            let until = epoch.addingTimeInterval(86400)
            try autoreleasepool {
                let schema = Schema(versionedSchema: ThoughtSchemaV7.self)
                let original = try ModelContainer(
                    for: schema, configurations: ModelConfiguration(
                        schema: schema,
                        url: url,
                        cloudKitDatabase: .none
                    )
                )
                let context = ModelContext(original)
                let row = ThoughtSchemaV7.ThoughtEntity(id: thoughtID, capturedAt: epoch)
                row.body = "Original words\nwith café and 🌱"
                row.title = "A title"
                row.listID = listID
                row.kindRaw = "habit"
                row.kindSourceRaw = "confirmed"
                row.cadenceRaw = HabitCadence.weekly.rawValue
                row.cadenceSourceRaw = "confirmed"
                row.stateCode = StoredState.code(for: .snoozed(until: until))
                row.streakCode = StoredStreak.code(for: Streak(count: 6, lastMarkedAt: epoch))
                row.lastActedAt = epoch
                row.dueAt = until
                row.snoozeCount = 3
                row.customLifetime = 43200
                context.insert(row)
                context.insert(ThoughtSchemaV7.ThoughtListEntity(
                    id: listID, name: "Together", listDescription: "Our reading", defaultKindRaw: "habit"
                ))
                try context.save()
            }
            let before = try NSPersistentStoreCoordinator.metadataForPersistentStore(
                ofType: NSSQLiteStoreType,
                at: url
            )
            try CollaborationStore.preserveBeforeUpgrade(at: url)
            let backup = url.deletingLastPathComponent().appending(path: "Fleeting-before-sharing.store")
            let recovery = try NSPersistentStoreCoordinator.metadataForPersistentStore(
                ofType: NSSQLiteStoreType,
                at: backup
            )
            #expect(recovery[NSStoreUUIDKey] as? String == before[NSStoreUUIDKey] as? String)
            try autoreleasepool { _ = try ModelContainerFactory.open(cloudKitDatabase: .none, url: url) }
            let store = try CollaborationStore(privateURL: url)
            let repository = CollaborationRepository(store: store)
            let row = try #require(try repository.thoughtRow(thoughtID))
            let thought = CollaborationMapping.read(row, listID: listID, sharing: nil)
            #expect(thought.body == "Original words\nwith café and 🌱")
            #expect(thought.title == "A title")
            #expect(thought.state == .snoozed(until: until))
            #expect(thought.streak == Streak(count: 6, lastMarkedAt: epoch))
            #expect(thought.cadence == .weekly)
            #expect(thought.cadenceSource == .confirmed)
            #expect(thought.kindSource == .confirmed)
            #expect(thought.dueAt == until)
            #expect(thought.snoozeCount == 3)
            #expect(thought.customLifetime == 43200)
            let list = try #require(try repository.listRow(listID))
            #expect(list.value(forKey: "listDescription") as? String == "Our reading")
            #expect(list.value(forKey: "defaultKindRaw") as? String == "habit")
            #expect(list.value(forKey: "sharingEnabled") as? Bool == false)
            #expect(row.value(forKey: "collection") == nil)
            #expect(store.privateStore
                .metadata[NSStoreUUIDKey] as? String == before[NSStoreUUIDKey] as? String)
            var updated = thought
            updated.archive(at: epoch)
            CollaborationMapping.write(updated, to: row)
            try repository.save()
            #expect(row.value(forKey: "stateRaw") as? String == "archived")
            // The recovery file is still the unmigrated V7 shape after new writes succeed.
            let preserved = try NSPersistentStoreCoordinator.metadataForPersistentStore(
                ofType: NSSQLiteStoreType,
                at: backup
            )
            #expect(preserved[NSStoreModelVersionHashesKey] as? [String: Data] ==
                before[NSStoreModelVersionHashesKey] as? [String: Data])
        }
    }

    @Test("version 4 thoughts survive adding the checklist and the new table accepts tasks")
    func version4ChecklistMigration() throws {
        try withTemporaryStore { url in
            try {
                let schema = Schema(versionedSchema: ThoughtSchemaV4.self)
                let container = try ModelContainer(
                    for: schema, configurations: ModelConfiguration(schema: schema, url: url)
                )
                let context = ModelContext(container)
                let thought = ThoughtSchemaV4.ThoughtEntity(id: UUID(), capturedAt: epoch)
                thought.body = "Existing habit"
                thought.kindRaw = "habit"
                thought.cadenceRaw = "weekly"
                context.insert(thought)
                try context.save()
            }()
            let schema = Schema(versionedSchema: ThoughtSchemaV8.self)
            let container = try ModelContainer(
                for: schema, migrationPlan: ThoughtMigrationPlan.self,
                configurations: ModelConfiguration(schema: schema, url: url)
            )
            let context = ModelContext(container)
            #expect(try context.fetch(FetchDescriptor<ThoughtEntity>()).first?.body == "Existing habit")
            #expect(try context.fetch(FetchDescriptor<ThoughtEntity>()).first?.cadenceRaw == "weekly")
            #expect(try context.fetch(FetchDescriptor<ThoughtSchemaV8.DailyTodoEntity>()).isEmpty)
            let task = DailyTodo(text: "Today's task", createdAt: epoch, day: PlanDay(rawValue: 20_260_922))
            let row = ThoughtSchemaV8.DailyTodoEntity(id: task.id, createdAt: epoch)
            row.payload = try JSONEncoder().encode(task)
            context.insert(row)
            try context.save()
            #expect(try context.fetch(FetchDescriptor<ThoughtSchemaV8.DailyTodoEntity>()).count == 1)
            #expect(try openCurrentStore(at: url).count == 1)
        }
    }
}

extension SchemaMigrationTests {
    @Test("version 5 assigns previously shared todos to Plan without changing other thoughts or history")
    func version5ListMigration() throws {
        try withTemporaryStore { url in
            let todoID = UUID()
            let ideaID = UUID()
            try {
                let schema = Schema(versionedSchema: ThoughtSchemaV5.self)
                let container = try ModelContainer(
                    for: schema,
                    configurations: ModelConfiguration(schema: schema, url: url)
                )
                let context = ModelContext(container)
                let todo = ThoughtSchemaV5.ThoughtEntity(id: todoID, capturedAt: epoch)
                todo.body = "Completed task"
                todo.kindRaw = "todo"
                todo.dueAt = epoch
                todo.stateCode = StoredState.code(for: .done(at: epoch))
                todo.isLive = false
                context.insert(todo)
                let idea = ThoughtSchemaV5.ThoughtEntity(id: ideaID, capturedAt: epoch)
                idea.body = "Keep these words"
                idea.kindRaw = "idea"
                context.insert(idea)
                try context.save()
            }()
            let migrated = try openCurrentStore(at: url)
            let todo = try #require(migrated.first { $0.id == todoID })
            #expect(todo.listID == ThoughtList.planID)
            #expect(todo.state == .done(at: epoch))
            #expect(todo.dueAt == epoch)
            #expect(todo.body == "Completed task")
            #expect(migrated.first { $0.id == ideaID }?.listID == nil)
            #expect(try openCurrentStore(at: url) == migrated)
        }
    }
}

extension SchemaMigrationTests {
    @Test("version 6 lists retain names, identity and membership with neutral metadata defaults")
    func version6ListMetadataMigration() throws {
        try withTemporaryStore { url in
            let listID = UUID()
            let thoughtID = UUID()
            try {
                let schema = Schema(versionedSchema: ThoughtSchemaV6.self)
                let container = try ModelContainer(
                    for: schema,
                    configurations: ModelConfiguration(schema: schema, url: url)
                )
                let context = ModelContext(container)
                context.insert(ThoughtSchemaV6.ThoughtListEntity(id: listID, name: "Writing"))
                let row = ThoughtSchemaV6.ThoughtEntity(id: thoughtID, capturedAt: epoch)
                row.body = "Existing draft"
                row.listID = listID
                context.insert(row)
                try context.save()
            }()
            let schema = Schema(versionedSchema: ThoughtSchemaV8.self)
            let container = try ModelContainer(
                for: schema,
                migrationPlan: ThoughtMigrationPlan.self,
                configurations: ModelConfiguration(schema: schema, url: url)
            )
            let context = ModelContext(container)
            let list = try #require(context.fetch(FetchDescriptor<ThoughtSchemaV8.ThoughtListEntity>()).first)
            #expect(list.id == listID)
            #expect(list.name == "Writing")
            #expect(list.listDescription.isEmpty)
            #expect(list.defaultKindRaw == "unsorted")
            let thought = try #require(context.fetch(FetchDescriptor<ThoughtEntity>()).first)
            #expect(thought.id == thoughtID)
            #expect(thought.listID == listID)
            #expect(thought.body == "Existing draft")
        }
    }
}
