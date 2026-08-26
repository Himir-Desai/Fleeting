import Foundation
import SwiftData

/// The stored form of a ``Core/Thought``.
///
/// Deliberately not the domain type. Every attribute carries a default and none is unique,
/// because CloudKit refuses both — constraints that belong to storage and must not reach the
/// domain (ADR-0003). Enum cases are flattened to a raw string plus an optional date so the
/// store stays queryable.
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
        sharpeningJSON: String?
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
    }
}
