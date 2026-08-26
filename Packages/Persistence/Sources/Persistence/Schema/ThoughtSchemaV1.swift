import Foundation
import SwiftData

/// The store as it shipped through Phase 6: local only, with lifecycle values spread across
/// separate columns.
///
/// Kept verbatim so the migration to ``ThoughtSchemaV2`` has a real source to read from and can
/// be tested against a store written by the shipped build.
enum ThoughtSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(1, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        [ThoughtEntity.self]
    }

    /// The stored form of a ``Core/Thought`` in version 1.
    @Model
    final class ThoughtEntity {
        var id: UUID = UUID()
        var body: String = ""
        var title: String?
        var kindRaw: String = "unsorted"
        var stateRaw: String = "inbox"
        var stateDate: Date?
        var capturedAt: Date = Date.distantPast
        var lastActedAt: Date = Date.distantPast
        var kindSourceRaw: String = "unclassified"
        var dueAt: Date?
        var streakCount: Int = 0
        var streakLastMarkedAt: Date?
        var sharpeningJSON: String?
        var snoozeCount: Int = 0

        init(
            id: UUID,
            body: String,
            title: String?,
            kindRaw: String,
            stateRaw: String,
            stateDate: Date?,
            capturedAt: Date,
            lastActedAt: Date,
            kindSourceRaw: String,
            dueAt: Date?,
            streakCount: Int,
            streakLastMarkedAt: Date?,
            sharpeningJSON: String?,
            snoozeCount: Int
        ) {
            self.id = id
            self.body = body
            self.title = title
            self.kindRaw = kindRaw
            self.stateRaw = stateRaw
            self.stateDate = stateDate
            self.capturedAt = capturedAt
            self.lastActedAt = lastActedAt
            self.kindSourceRaw = kindSourceRaw
            self.dueAt = dueAt
            self.streakCount = streakCount
            self.streakLastMarkedAt = streakLastMarkedAt
            self.sharpeningJSON = sharpeningJSON
            self.snoozeCount = snoozeCount
        }
    }
}
