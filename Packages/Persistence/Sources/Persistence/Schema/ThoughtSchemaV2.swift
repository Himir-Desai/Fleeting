import Foundation
import SwiftData

/// The store as it syncs: lifecycle values collapsed into single columns so iCloud cannot merge
/// half of one device's change with half of another's.
///
/// Version 1's columns are still present and still written. A build from before the migration
/// reads them and behaves correctly, which is what makes rolling back possible (ADR-0019).
enum ThoughtSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(2, 0, 0)
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
