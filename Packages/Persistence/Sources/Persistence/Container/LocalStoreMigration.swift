import Foundation
import SwiftData

/// Imports the pre-App-Group database once, keeping its file as a recovery copy.
enum LocalStoreMigration {
    static func migrate(from sourceURL: URL, to destinationURL: URL) throws {
        let marker = sourceURL.appendingPathExtension("imported-to-app-group")
        let files = FileManager.default
        guard sourceURL != destinationURL,
              files.fileExists(atPath: sourceURL.path),
              !files.fileExists(atPath: marker.path) else { return }
        try importRecords(from: sourceURL, to: destinationURL)
        // Written only after the destination transaction succeeds. A retry deduplicates by ID.
        try Data().write(to: marker, options: .atomic)
    }

    private static func importRecords(from sourceURL: URL, to destinationURL: URL) throws {
        let source = try ModelContainerFactory.open(cloudKitDatabase: .none, url: sourceURL)
        let destination = try ModelContainerFactory.open(cloudKitDatabase: .none, url: destinationURL)
        let old = ModelContext(source)
        let new = ModelContext(destination)
        var ids = try Set(new.fetch(FetchDescriptor<ThoughtEntity>()).map(\.id))
        for row in try old.fetch(FetchDescriptor<ThoughtEntity>()) where ids.insert(row.id).inserted {
            new.insert(ThoughtEntity(row.domain))
        }
        var listIDs = try Set(new.fetch(FetchDescriptor<ThoughtSchemaV8.ThoughtListEntity>()).map(\.id))
        for row in try old.fetch(FetchDescriptor<ThoughtSchemaV8.ThoughtListEntity>())
            where listIDs.insert(row.id).inserted
        {
            new.insert(ThoughtSchemaV8.ThoughtListEntity(
                id: row.id,
                name: row.name,
                listDescription: row.listDescription,
                defaultKindRaw: row.defaultKindRaw
            ))
        }
        var legacyIDs = try Set(new.fetch(FetchDescriptor<ThoughtSchemaV8.DailyTodoEntity>()).map(\.id))
        for row in try old.fetch(FetchDescriptor<ThoughtSchemaV8.DailyTodoEntity>())
            where !ids.contains(row.id) && legacyIDs.insert(row.id).inserted
        {
            let copy = ThoughtSchemaV8.DailyTodoEntity(id: row.id, createdAt: row.createdAt)
            copy.payload = row.payload
            new.insert(copy)
        }
        try new.save()
    }
}
