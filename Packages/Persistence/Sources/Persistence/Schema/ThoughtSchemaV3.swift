import Foundation
import SwiftData

/// Version 2 plus a per-thought lifetime override.
///
/// The one new column, `customLifetime`, is optional with a default, so moving a version 2 store
/// forward is a lightweight migration and CloudKit accepts the schema. Version 1's and version 2's
/// columns are all still present and written, so an older build reads correct data (ADR-0019).
enum ThoughtSchemaV3: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(3, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        [ThoughtEntity.self]
    }

    /// The stored form of a ``Core/Thought``.
    ///
    /// Deliberately not the domain type. Every attribute carries a default and none is unique,
    /// because CloudKit refuses both — constraints that belong to storage and must not reach the
    /// domain (ADR-0003).
    @Model
    final class ThoughtEntity {
        var id: UUID = UUID()
        var body: String = ""
        var title: String?
        var kindRaw: String = "unsorted"
        var capturedAt: Date = Date.distantPast
        var lastActedAt: Date = Date.distantPast
        var kindSourceRaw: String = "unclassified"
        var dueAt: Date?
        var sharpeningJSON: String?
        var snoozeCount: Int = 0

        /// A capture-time lifetime override in seconds, or `nil` to decay at the kind's rate.
        var customLifetime: Double?

        /// Lifecycle position and the date belonging to it, encoded as one value.
        var stateCode: String = "inbox"

        /// Streak length and its last-marked date, encoded as one value, or `nil` for no streak.
        var streakCode: String?

        /// Whether the thought is still in play. Derived from `stateCode` on every write so
        /// scopes can be filtered by the store rather than in memory.
        var isLive: Bool = true

        /// Version 1's lifecycle columns, still written so an older build reads correct data.
        var stateRaw: String = "inbox"
        var stateDate: Date?
        var streakCount: Int = 0
        var streakLastMarkedAt: Date?

        /// Creates an empty row. Contents are written by the mapping layer.
        /// - Parameters:
        ///   - id: The thought's identity, which never changes.
        ///   - capturedAt: When the thought was captured, which never changes.
        init(id: UUID, capturedAt: Date) {
            self.id = id
            self.capturedAt = capturedAt
        }
    }
}
