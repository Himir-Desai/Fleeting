import Foundation
import SwiftData

/// Named collections and explicit thought membership alongside legacy checklist records.
enum ThoughtSchemaV6: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(6, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        [ThoughtEntity.self, DailyTodoEntity.self, ThoughtListEntity.self]
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
        var listID: UUID?
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

        /// How often a habit is meant to be kept, or `nil` for the default.
        ///
        /// Optional rather than defaulted to "daily" so a row written by version 3 is
        /// distinguishable from one where daily was actually chosen — both behave as daily, but
        /// only the second is a decision.
        var cadenceRaw: String?

        /// Where the cadence came from, so a chosen one is never overwritten by classification.
        var cadenceSourceRaw: String?

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

    /// A user-created collection. Plan is represented by its stable domain identifier.
    @Model
    final class ThoughtListEntity {
        var id: UUID = UUID()
        var name: String = ""

        init(id: UUID, name: String) {
            self.id = id
            self.name = name
        }
    }

    /// A legacy checklist record imported into the shared thought store on first read.
    @Model
    final class DailyTodoEntity {
        var id: UUID = UUID()
        var createdAt: Date = Date.distantPast
        var payload: Data = Data()

        init(id: UUID, createdAt: Date) {
            self.id = id
            self.createdAt = createdAt
        }
    }
}
