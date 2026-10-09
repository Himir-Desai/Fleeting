import CloudKit
import Core
import CoreData
import Foundation

/// Personal activity overlays that never enter a shared list graph.
extension CollaborationRepository {
    func activity(for thought: Thought, create: Bool) throws -> NSManagedObject? {
        let predicate = NSPredicate(format: "thoughtID == %@", thought.id as NSUUID)
        let matches = try fetch("MemberActivityEntity", predicate: predicate, privateOnly: true)
            .sorted(by: { lhs, rhs in
                let left = lhs.value(forKey: "updatedAt") as? Date ?? .distantPast
                let right = rhs.value(forKey: "updatedAt") as? Date ?? .distantPast
                if left != right {
                    return left > right
                }
                let leftID = (lhs.value(forKey: "id") as? UUID)?.uuidString ?? ""
                let rightID = (rhs.value(forKey: "id") as? UUID)?.uuidString ?? ""
                return leftID < rightID
            })
        if let existing = matches.first {
            return existing
        }
        guard create else { return nil }
        let row = NSEntityDescription.insertNewObject(forEntityName: "MemberActivityEntity", into: context)
        context.assign(row, to: store.privateStore)
        row.setValue(UUID(), forKey: "id"); row.setValue(thought.id, forKey: "thoughtID")
        row.setValue(thought.listID, forKey: "listID")
        return row
    }

    func keepPersonalProgress(_ thought: Thought) throws {
        if let row = try activity(for: thought, create: true) {
            writeActivity(thought, to: row)
        }
    }

    func writeActivity(_ thought: Thought, to row: NSManagedObject) {
        row.setValue(clock.now, forKey: "updatedAt")
        row.setValue(thought.listID, forKey: "listID")
        row.setValue(StoredStreak.code(for: thought.streak), forKey: "streakCode")
        row.setValue(thought.lastActedAt, forKey: "lastActedAt")
        row.setValue(thought.snoozeCount, forKey: "snoozeCount")
        if case let .snoozed(until) = thought.state {
            row.setValue(until, forKey: "hiddenUntil")
        } else {
            row.setValue(nil, forKey: "hiddenUntil")
        }
    }

    func applying(_ activity: NSManagedObject, to thought: Thought) -> Thought {
        var state = thought.state
        if let until = activity.value(forKey: "hiddenUntil") as? Date, state.isLive {
            state = .snoozed(until: until)
        }
        return Thought(
            id: thought.id,
            body: thought.body,
            capturedAt: thought.capturedAt,
            kind: thought.kind,
            state: state,
            title: thought.title,
            lastActedAt: activity.value(forKey: "lastActedAt") as? Date ?? thought.lastActedAt,
            kindSource: thought.kindSource,
            dueAt: thought.dueAt,
            streak: StoredStreak.streak(code: activity.value(forKey: "streakCode") as? String),
            cadence: thought.cadence,
            cadenceSource: thought.cadenceSource,
            sharpening: thought.sharpening,
            snoozeCount: activity.value(forKey: "snoozeCount") as? Int ?? 0,
            customLifetime: thought.customLifetime,
            listID: thought.listID,
            sharing: thought.sharing
        )
    }

    func commonFields(of thought: Thought, basedOn base: Thought, initialShare: Bool = false) -> Thought {
        let state: ThoughtState = if case .snoozed = thought.state {
            base.state
        } else {
            thought.state
        }
        return Thought(
            id: thought.id,
            body: thought.body,
            capturedAt: thought.capturedAt,
            kind: thought.kind,
            state: state,
            title: thought.title,
            lastActedAt: initialShare ? thought.capturedAt : base.lastActedAt,
            kindSource: thought.kindSource,
            dueAt: thought.dueAt,
            streak: nil,
            cadence: thought.cadence,
            cadenceSource: thought.cadenceSource,
            sharpening: thought.sharpening,
            snoozeCount: 0,
            customLifetime: thought.customLifetime,
            listID: thought.listID
        )
    }
}
