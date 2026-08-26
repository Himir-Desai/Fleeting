import Core
import Foundation
import SwiftData

/// Builds the SwiftData containers the app and its tests run against.
public enum ModelContainerFactory {
    /// The App Group the app and its widgets share.
    ///
    /// Widgets run in their own process, so the store has to live somewhere both can reach.
    public static let appGroupIdentifier = "group.com.himirdesai.Fleeting"

    /// The CloudKit container holding the user's private database.
    public static let cloudContainerIdentifier = "iCloud.com.himirdesai.Fleeting"

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

    /// The schema the app reads and writes.
    private static var schema: Schema {
        Schema(versionedSchema: ThoughtSchemaV2.self)
    }

    /// The on-disk store the app uses, syncing through iCloud when it can.
    ///
    /// Attaches iCloud only when the App Group container is reachable, and falls back to a
    /// device-local store carrying the same data. A build that cannot reach iCloud — unsigned,
    /// unentitled, or with iCloud Drive turned off — must still capture (ADR-0019).
    ///
    /// The App Group is a proxy for the entitlement being live at all: both are written by the
    /// same entitlements file, and a build that had them stripped has neither. CloudKit cannot be
    /// asked directly, because an unentitled process is trapped rather than told.
    /// - Parameters:
    ///   - resettingFirst: When `true`, removes any existing store before opening, so a UI test
    ///     can begin from a known-empty state.
    ///   - syncing: When `false`, opens the same file without attaching iCloud. Widgets pass
    ///     `false`: they only read, and a second process mirroring CloudKit on every timeline
    ///     refresh would spend the app's request budget for nothing.
    /// - Returns: The container, and what had to be given up to open it.
    /// - Throws: ``PersistenceError`` if neither store can be opened.
    public static func store(
        resettingFirst: Bool = false,
        syncing: Bool = true
    ) throws -> OpenedStore {
        let directory = storeURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if resettingFirst {
            removeStoreFiles(in: directory)
        }

        guard syncing, isShared else {
            return try OpenedStore(
                container: open(cloudKitDatabase: .none),
                isShared: isShared,
                cloud: .unavailable(.notAttached)
            )
        }

        if let container = try? open(cloudKitDatabase: .private(cloudContainerIdentifier)) {
            return OpenedStore(container: container, isShared: isShared, cloud: .attached)
        }

        return try OpenedStore(
            container: open(cloudKitDatabase: .none),
            isShared: isShared,
            cloud: .unavailable(.refusedByCloudKit)
        )
    }

    /// Opens the on-disk store with a given iCloud configuration, migrating it if needed.
    /// - Parameter cloudKitDatabase: Which CloudKit database to back the store with.
    /// - Returns: The opened container.
    private static func open(
        cloudKitDatabase: ModelConfiguration.CloudKitDatabase
    ) throws -> ModelContainer {
        try ModelContainer(
            for: schema,
            migrationPlan: ThoughtMigrationPlan.self,
            configurations: ModelConfiguration(
                schema: schema,
                url: storeURL,
                cloudKitDatabase: cloudKitDatabase
            )
        )
    }

    /// A container that never touches disk, for tests and SwiftUI previews.
    ///
    /// Deliberately built without ``ThoughtMigrationPlan``: a store created in memory is empty and
    /// already at the current version, and running a plan against one makes SwiftData rebuild a
    /// store that parallel tests are sharing.
    /// - Returns: A container discarded when the process ends.
    public static func inMemory() throws -> ModelContainer {
        try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
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
