#if DEBUG
    import Core
    import CoreData
    import Foundation

    public extension CollaborationRepository {
        /// Seeds local shared-store content for unsigned UI previews without contacting iCloud.
        func seedSharedPreview(at date: Date) throws {
            let listID = UUID()
            let list = NSEntityDescription.insertNewObject(
                forEntityName: "ThoughtListEntity",
                into: store.context
            )
            store.context.assign(list, to: store.sharedStore)
            list.setValue(listID, forKey: "id")
            list.setValue("Shared reading", forKey: "name")
            list.setValue("Books we read together", forKey: "listDescription")
            list.setValue("habit", forKey: "defaultKindRaw")
            let row = NSEntityDescription.insertNewObject(forEntityName: "ThoughtEntity", into: store.context)
            store.context.assign(row, to: store.sharedStore)
            CollaborationMapping.write(
                Thought(body: "Read together", capturedAt: date, kind: .habit, listID: listID),
                to: row
            )
            row.setValue(list, forKey: "collection")
            try save()
        }
    }
#endif
