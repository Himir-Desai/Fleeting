import Foundation
import SwiftData

/// How an existing store is brought up to the current schema version.
enum ThoughtMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [ThoughtSchemaV1.self, ThoughtSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [version1To2]
    }

    /// Fills in version 2's combined lifecycle columns from version 1's separate ones.
    ///
    /// Custom rather than lightweight: a lightweight migration would leave every row at the
    /// default `inbox`, returning the entire archive to the inbox.
    private static let version1To2 = MigrationStage.custom(
        fromVersion: ThoughtSchemaV1.self,
        toVersion: ThoughtSchemaV2.self,
        willMigrate: nil,
        didMigrate: { context in
            let rows = try context.fetch(FetchDescriptor<ThoughtSchemaV2.ThoughtEntity>())
            for row in rows {
                row.stateCode = StoredState.code(raw: row.stateRaw, date: row.stateDate)
                row.isLive = StoredState.isLive(code: row.stateCode)
                row.streakCode = StoredStreak.code(
                    count: row.streakCount,
                    lastMarkedAt: row.streakLastMarkedAt
                )
            }
            try context.save()
        }
    )
}
