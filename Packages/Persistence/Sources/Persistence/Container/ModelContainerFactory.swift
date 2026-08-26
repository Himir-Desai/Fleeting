import Foundation
import SwiftData

/// Builds the SwiftData containers the app and its tests run against.
public enum ModelContainerFactory {
    /// The App Group the app and its widgets share.
    ///
    /// Widgets run in their own process, so the store has to live somewhere both can reach.
    public static let appGroupIdentifier = "group.com.himirdesai.Fleeting"

    /// Where the on-disk store lives. Named explicitly so it can be removed deterministically.
    ///
    /// Falls back to the app's own support directory when the App Group is unavailable — an
    /// unsigned build or a missing entitlement must degrade to a working app, not a broken one.
    private static var storeURL: URL {
        let shared = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        )
        return (shared ?? URL.applicationSupportDirectory).appending(path: "Fleeting.store")
    }

    /// Whether the store is in the shared container, and therefore visible to widgets.
    public static var isShared: Bool {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) != nil
    }

    /// The on-disk store the app uses. CloudKit sync is attached in Phase 7.
    /// - Parameter resettingFirst: When `true`, removes any existing store before opening, so a
    ///   UI test can begin from a known-empty state.
    /// - Returns: A container backed by a file in the app's support directory.
    public static func store(resettingFirst: Bool = false) throws -> ModelContainer {
        let directory = storeURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if resettingFirst {
            removeStoreFiles(in: directory)
        }

        return try ModelContainer(
            for: ThoughtEntity.self,
            configurations: ModelConfiguration(url: storeURL)
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

    /// Removes the store and the SQLite sidecar files that travel with it.
    /// - Parameter directory: The directory holding the store.
    private static func removeStoreFiles(in directory: URL) {
        let manager = FileManager.default
        let names = (try? manager.contentsOfDirectory(atPath: directory.path)) ?? []
        let storeName = storeURL.lastPathComponent
        for name in names where name.hasPrefix(storeName) {
            try? manager.removeItem(at: directory.appending(path: name))
        }
    }
}
