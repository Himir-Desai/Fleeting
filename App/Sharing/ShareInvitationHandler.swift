import CloudKit
import UIKit

/// Queues system share invitations until the app's composition root is ready.
@MainActor
final class ShareInvitationHandler {
    static let shared = ShareInvitationHandler()
    private var pending: [CKShare.Metadata] = []
    var coordinator: ListSharingCoordinator? {
        didSet {
            guard let coordinator else { return }
            let queued = pending; pending.removeAll()
            for metadata in queued {
                Task { await coordinator.accept(metadata) }
            }
        }
    }

    func receive(_ metadata: CKShare.Metadata) {
        if let coordinator {
            Task { await coordinator.accept(metadata) }
        } else {
            pending.append(metadata)
        }
    }
}

/// Keeps SwiftUI scene creation while registering the native share-acceptance delegate.
final class SharingApplicationDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting session: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: session.role)
        configuration.delegateClass = SharingSceneDelegate.self
        return configuration
    }
}

/// Receives invitations on cold launch and while a scene is already running.
final class SharingSceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        if let metadata = options.cloudKitShareMetadata {
            ShareInvitationHandler.shared.receive(metadata)
        }
    }

    func windowScene(
        _ windowScene: UIWindowScene,
        userDidAcceptCloudKitShareWith metadata: CKShare.Metadata
    ) {
        ShareInvitationHandler.shared.receive(metadata)
    }
}
