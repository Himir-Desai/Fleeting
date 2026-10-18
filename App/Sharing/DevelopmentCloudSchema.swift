#if DEBUG
    import CloudKit
    import Foundation
    import OSLog
    import Persistence

    extension AppEnvironment {
        /// Initializes model changes only when a signed development run explicitly requests it.
        func initializeCloudSchemaIfRequested() {
            if ProcessInfo.processInfo.arguments.contains("--initialize-cloudkit-sharing-schema") {
                Task { await initializeSharingSchema() }
            }
            guard ProcessInfo.processInfo.arguments.contains("--initialize-cloudkit-schema") else { return }
            let logger = Logger(subsystem: "com.himirdesai.Fleeting", category: "CloudSchema")
            guard let repository = thoughts as? CollaborationRepository, repository.store.cloudEnabled else {
                logger.error("Schema initialization requires a signed, cloud-enabled development build.")
                return
            }
            do {
                try repository.store.container.initializeCloudKitSchema()
                logger
                    .info(
                        "Development schema initialized. Inspect it in CloudKit Console before deployment."
                    )
            } catch {
                logger.error("Schema initialization failed: \(error.localizedDescription, privacy: .public)")
            }
        }

        /// Creates the sharing system type in Development using an empty, disposable zone.
        private func initializeSharingSchema() async {
            let logger = Logger(subsystem: "com.himirdesai.Fleeting", category: "CloudSchema")
            guard let repository = thoughts as? CollaborationRepository, repository.store.cloudEnabled else {
                logger.error("Sharing schema initialization requires a signed Development build.")
                return
            }
            // This explicit DEBUG-only launch action must be run with Development entitlements.
            // A separate empty zone never touches Core Data zones or a user's list graph.
            let database = CKContainer(identifier: CollaborationStore.cloudContainerIdentifier)
                .privateCloudDatabase
            let zone = CKRecordZone(zoneName: "FleetingSharingSchema-\(UUID().uuidString)")
            do {
                _ = try await database.save(zone)
                let share = CKShare(recordZoneID: zone.zoneID)
                share.publicPermission = .none
                _ = try await database.save(share)
                logger.info("Sharing schema initialized: cloudkit.share. Deploy this type to Production.")
            } catch {
                logger
                    .error(
                        "Sharing schema initialization failed: \(error.localizedDescription, privacy: .public)"
                    )
            }
            do {
                _ = try await database.deleteRecordZone(withID: zone.zoneID)
            } catch {
                logger
                    .error(
                        "Disposable sharing-zone cleanup failed: \(error.localizedDescription, privacy: .public)"
                    )
            }
        }
    }
#endif
