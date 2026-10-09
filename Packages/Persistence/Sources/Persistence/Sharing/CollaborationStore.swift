import CloudKit
import CoreData
import Foundation
import OSLog
import SwiftData

/// One native Core Data foundation for the existing private store and accepted shared zones.
@MainActor
public final class CollaborationStore {
    public static let cloudContainerIdentifier = ModelContainerFactory.cloudContainerIdentifier
    public let container: NSPersistentCloudKitContainer
    public let cloudEnabled: Bool
    public let isSharedStorage: Bool
    public var privateStore: NSPersistentStore {
        container.persistentStoreCoordinator.persistentStores[0]
    }

    public var sharedStore: NSPersistentStore {
        container.persistentStoreCoordinator.persistentStores[1]
    }

    var context: NSManagedObjectContext {
        container.viewContext
    }

    public init(privateURL: URL? = nil, syncing: Bool = false, inMemory: Bool = false) throws {
        cloudEnabled = syncing && !inMemory
        isSharedStorage = !inMemory && (privateURL ?? ModelContainerFactory.storeURL) == ModelContainerFactory
            .storeURL
            && ModelContainerFactory.isShared
        container = try NSPersistentCloudKitContainer(
            name: "Fleeting",
            managedObjectModel: CollaborationModel.make()
        )
        let url = privateURL ?? ModelContainerFactory.storeURL
        if !inMemory {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        }
        container.persistentStoreDescriptions = [CKDatabase.Scope.private, .shared].map { scope in
            let location = scope == .private ? url : url.deletingLastPathComponent()
                .appending(path: "Fleeting-shared.store")
            let description = NSPersistentStoreDescription(url: location)
            description.type = inMemory ? NSInMemoryStoreType : NSSQLiteStoreType
            description.shouldAddStoreAsynchronously = false
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(
                true as NSNumber,
                forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey
            )
            if syncing, !inMemory {
                let options = NSPersistentCloudKitContainerOptions(containerIdentifier: Self
                    .cloudContainerIdentifier)
                options.databaseScope = scope
                description.cloudKitContainerOptions = options
            }
            return description
        }
        var loadError: (any Error)?
        container.loadPersistentStores { _, error in
            if let error {
                loadError = error
            }
        }
        if let loadError {
            for loaded in container.persistentStoreCoordinator.persistentStores {
                try? container.persistentStoreCoordinator.remove(loaded)
            }
            throw loadError
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        container.viewContext.stalenessInterval = 0
    }

    /// Upgrades through the existing versioned migration, then releases SwiftData before Core Data opens it.
    public static func open(resettingFirst: Bool = false, syncing: Bool = true) throws -> CollaborationStore {
        var url = ModelContainerFactory.storeURL
        if resettingFirst {
            let files = FileManager.default
            let directory = url.deletingLastPathComponent()
            if files.fileExists(atPath: directory.path) {
                let entries = try files.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
                for file in entries.filter({ $0.lastPathComponent.hasPrefix("Fleeting-shared.store") }) {
                    try files.removeItem(at: file)
                }
            }
        }
        if syncing, ModelContainerFactory.isShared, !resettingFirst {
            let local = URL.applicationSupportDirectory.appending(path: "Fleeting.store")
            do {
                try preserveBeforeUpgrade(at: local)
                try preserveBeforeUpgrade(at: url)
                try LocalStoreMigration.migrate(from: local, to: url)
            } catch {
                Logger(subsystem: "com.himirdesai.Fleeting", category: "Storage")
                    .error("App Group import unavailable: \(error.localizedDescription, privacy: .public)")
                // Keep writing the original durable store if importing it could not complete.
                url = local
            }
        }
        if !resettingFirst {
            try preserveBeforeUpgrade(at: url)
        }
        try autoreleasepool {
            if resettingFirst {
                _ = try ModelContainerFactory.store(resettingFirst: true, syncing: false)
            } else {
                _ = try ModelContainerFactory.open(cloudKitDatabase: .none, url: url)
            }
        }
        let attachCloud = syncing && ModelContainerFactory.isShared && url == ModelContainerFactory.storeURL
        do {
            return try CollaborationStore(privateURL: url, syncing: attachCloud)
        } catch {
            guard attachCloud else { throw error }
            Logger(subsystem: "com.himirdesai.Fleeting", category: "Sync")
                .error("Cloud attachment unavailable: \(error.localizedDescription, privacy: .public)")
            return try CollaborationStore(privateURL: url, syncing: false)
        }
    }

    /// Snapshots an older SQLite store, including its journal, before the versioned upgrade.
    static func preserveBeforeUpgrade(at url: URL) throws {
        let files = FileManager.default
        guard files.fileExists(atPath: url.path) else { return }
        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType, at: url, options: nil
        )
        guard try !CollaborationModel.make().isConfiguration(
            withName: nil,
            compatibleWithStoreMetadata: metadata
        )
        else { return }
        let backup = url.deletingLastPathComponent().appending(path: "Fleeting-before-sharing.store")
        guard !files.fileExists(atPath: backup.path) else { return }
        let coordinator = try NSPersistentStoreCoordinator(managedObjectModel: CollaborationModel.make())
        try coordinator.replacePersistentStore(
            at: backup, destinationOptions: nil, withPersistentStoreFrom: url,
            sourceOptions: nil, ofType: NSSQLiteStoreType
        )
    }
}
