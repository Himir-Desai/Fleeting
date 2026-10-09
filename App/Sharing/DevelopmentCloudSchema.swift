#if DEBUG
    import Foundation
    import OSLog
    import Persistence

    extension AppEnvironment {
        /// Initializes model changes only when a signed development run explicitly requests it.
        func initializeCloudSchemaIfRequested() {
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
    }
#endif
