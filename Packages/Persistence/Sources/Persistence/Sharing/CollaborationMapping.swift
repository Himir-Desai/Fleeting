import Core
import CoreData
import Foundation

/// Encodes complete domain thoughts without changing their text, identity or history.
enum CollaborationMapping {
    static func write(_ thought: Thought, to row: NSManagedObject) {
        let legacy = StoredState.components(of: thought.state)
        let values: [String: Any?] = [
            "id": thought.id, "body": thought.body, "capturedAt": thought.capturedAt, "title": thought.title,
            "kindRaw": thought.kind.rawValue, "kindSourceRaw": thought.kindSource.rawValue,
            "lastActedAt": thought.lastActedAt, "dueAt": thought.dueAt,
            "stateCode": StoredState.code(for: thought.state),
            "streakCode": StoredStreak.code(for: thought.streak), "cadenceRaw": thought.cadence.rawValue,
            "cadenceSourceRaw": thought.cadenceSource.rawValue,
            "sharpeningJSON": StoredSharpening.encode(thought.sharpening),
            "isLive": thought.state.isLive, "listID": thought.listID, "snoozeCount": thought.snoozeCount,
            "customLifetime": thought.customLifetime,
            "stateRaw": legacy.raw, "stateDate": legacy.date,
            "streakCount": thought.streak?.count ?? 0,
            "streakLastMarkedAt": thought.streak?.lastMarkedAt
        ]
        for (key, value) in values {
            row.setValue(value, forKey: key)
        }
    }

    static func read(_ row: NSManagedObject, listID: UUID?, sharing: ListSharing?) -> Thought {
        Thought(
            id: row.value(forKey: "id") as? UUID ?? UUID(),
            body: row.value(forKey: "body") as? String ?? "",
            capturedAt: row.value(forKey: "capturedAt") as? Date ?? .distantPast,
            kind: ThoughtKind(rawValue: row.value(forKey: "kindRaw") as? String ?? "") ?? .unsorted,
            state: StoredState.state(code: row.value(forKey: "stateCode") as? String ?? "inbox"),
            title: row.value(forKey: "title") as? String,
            lastActedAt: row.value(forKey: "lastActedAt") as? Date ?? .distantPast,
            kindSource: KindSource(rawValue: row.value(forKey: "kindSourceRaw") as? String ?? "") ??
                .unclassified,
            dueAt: row.value(forKey: "dueAt") as? Date,
            streak: StoredStreak.streak(code: row.value(forKey: "streakCode") as? String),
            cadence: HabitCadence(rawValue: row.value(forKey: "cadenceRaw") as? String ?? "") ?? .default,
            cadenceSource: KindSource(rawValue: row.value(forKey: "cadenceSourceRaw") as? String ?? "") ??
                .unclassified,
            sharpening: StoredSharpening.decode(row.value(forKey: "sharpeningJSON") as? String),
            snoozeCount: row.value(forKey: "snoozeCount") as? Int ?? 0,
            customLifetime: row.value(forKey: "customLifetime") as? Double,
            listID: listID,
            sharing: sharing
        )
    }
}
