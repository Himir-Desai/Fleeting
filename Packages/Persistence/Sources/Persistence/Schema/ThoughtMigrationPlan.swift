import Core
import Foundation
import SwiftData

/// How an existing store is brought up to the current schema version.
enum ThoughtMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [
            ThoughtSchemaV1.self,
            ThoughtSchemaV2.self,
            ThoughtSchemaV3.self,
            ThoughtSchemaV4.self,
            ThoughtSchemaV5.self,
            ThoughtSchemaV6.self,
            ThoughtSchemaV7.self,
            ThoughtSchemaV8.self
        ]
    }

    static var stages: [MigrationStage] {
        [version1To2, version2To3, version3To4, version4To5, version5To6, version6To7, version7To8]
    }

    /// Adds optional sharing graph links and private member activity without moving records.
    private static let version7To8 = MigrationStage.lightweight(
        fromVersion: ThoughtSchemaV7.self,
        toVersion: ThoughtSchemaV8.self
    )

    /// Adds metadata with neutral defaults, preserving list identities and memberships.
    private static let version6To7 = MigrationStage.lightweight(
        fromVersion: ThoughtSchemaV6.self, toVersion: ThoughtSchemaV7.self
    )

    /// Keeps every previously shared to-do in Plan, including completion and archived history.
    private static let version5To6 = MigrationStage.custom(
        fromVersion: ThoughtSchemaV5.self,
        toVersion: ThoughtSchemaV6.self,
        willMigrate: nil,
        didMigrate: { context in
            for row in try context.fetch(FetchDescriptor<ThoughtSchemaV6.ThoughtEntity>())
                where row.kindRaw == "todo"
            {
                row.listID = ThoughtList.planID
            }
            try context.save()
        }
    )

    /// Adds the daily checklist without changing existing thoughts.
    private static let version4To5 = MigrationStage.lightweight(
        fromVersion: ThoughtSchemaV4.self,
        toVersion: ThoughtSchemaV5.self
    )

    /// Adds version 4's optional `cadenceRaw` column.
    ///
    /// Lightweight rather than custom: the new attribute is optional with a default, so existing
    /// rows migrate to `nil` — no cadence chosen, which behaves as daily and is exactly the
    /// previous behaviour for every habit already stored.
    private static let version3To4 = MigrationStage.lightweight(
        fromVersion: ThoughtSchemaV3.self,
        toVersion: ThoughtSchemaV4.self
    )

    /// Adds version 3's optional `customLifetime` column.
    ///
    /// Lightweight rather than custom: the new attribute is optional with a default, so existing
    /// rows migrate to `nil` — no per-thought override, which is exactly the previous behaviour.
    private static let version2To3 = MigrationStage.lightweight(
        fromVersion: ThoughtSchemaV2.self,
        toVersion: ThoughtSchemaV3.self
    )

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
