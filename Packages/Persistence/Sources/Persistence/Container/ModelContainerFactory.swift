import Foundation
import SwiftData

/// Builds the SwiftData containers the app and its tests run against.
public enum ModelContainerFactory {
    /// The on-disk store the app uses. CloudKit sync is attached in Phase 7.
    /// - Returns: A container backed by a file in the app's support directory.
    public static func store() throws -> ModelContainer {
        try ModelContainer(
            for: ThoughtEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: false)
        )
    }

    /// A container that never touches disk, for tests and SwiftUI previews.
    /// - Returns: A container discarded when the process ends.
    public static func inMemory() throws -> ModelContainer {
        try ModelContainer(
            for: ThoughtEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }
}
