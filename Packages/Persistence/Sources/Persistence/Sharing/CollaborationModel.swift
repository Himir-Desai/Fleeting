import CoreData
import SwiftData

/// Builds the exact Core Data model that backs Fleeting's versioned SwiftData schema.
enum CollaborationModel {
    static func make() throws -> NSManagedObjectModel {
        guard let model = NSManagedObjectModel.makeManagedObjectModel(for: ThoughtSchemaV8.models) else {
            throw CocoaError(.persistentStoreInvalidType)
        }
        return model
    }
}
