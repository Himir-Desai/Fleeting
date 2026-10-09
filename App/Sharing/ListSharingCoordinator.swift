import CloudKit
import Core
import DesignSystem
import Persistence
import SwiftUI
import UIKit

/// Presents Apple's invitation, participant-management and leave-sharing screens.
@MainActor
final class ListSharingCoordinator: NSObject, ListSharingService, UICloudSharingControllerDelegate {
    private let repository: CollaborationRepository
    private let changes: ThoughtChangeNotifier
    private var activeListID: UUID?
    private var isPreparing = false
    private var acceptedShareID: CKRecord.ID?
    private var pendingError: (any Error)?
    var onAccepted: ((UUID?) -> Void)?

    init(repository: CollaborationRepository, changes: ThoughtChangeNotifier) {
        self.repository = repository
        self.changes = changes
    }

    func shareList(_ list: ThoughtList) async {
        guard !isPreparing else { return }
        isPreparing = true
        defer { isPreparing = false }
        let source = Self.presenter
        do {
            let handle = try await repository.prepareShare(listID: list.id)
            activeListID = list.id
            changes.notify()
            guard let presenter = source, presenter.viewIfLoaded?.window != nil,
                  Self.presenter === presenter else { return }
            let controller = UICloudSharingController(share: handle.share, container: handle.container)
            controller.delegate = self
            controller.view.tintColor = UIColor(Palette.accentText)
            controller.availablePermissions = [.allowPrivate, .allowPublic, .allowReadOnly, .allowReadWrite]
            controller.popoverPresentationController?.sourceView = presenter.view
            controller.popoverPresentationController?.sourceRect = CGRect(
                x: presenter.view.bounds.midX,
                y: presenter.view.bounds.midY,
                width: 1,
                height: 1
            )
            controller.popoverPresentationController?.permittedArrowDirections = []
            presenter.present(controller, animated: true)
        } catch {
            guard let source, source.viewIfLoaded?.window != nil, Self.presenter === source else { return }
            show(error)
        }
    }

    func accept(_ metadata: CKShare.Metadata) async {
        do {
            try await repository.acceptShare(metadata)
            acceptedShareID = metadata.share.recordID
            changes.notify()
            if !revealAcceptedList() {
                onAccepted?(nil)
            }
        } catch { show(error) }
    }

    /// Follows delayed shared-zone imports to the exact list that was invited.
    func observeAcceptedLists() async {
        let stream = changes.changes
        _ = revealAcceptedList()
        for await _ in stream {
            _ = revealAcceptedList()
        }
    }

    private func revealAcceptedList() -> Bool {
        guard let acceptedShareID, let onAccepted,
              let id = try? repository.acceptedListID(for: acceptedShareID) else { return false }
        self.acceptedShareID = nil
        onAccepted(id)
        return true
    }

    func itemTitle(for csc: UICloudSharingController) -> String? {
        csc
            .share?[CKShare.SystemFieldKey.title] as? String
    }

    func cloudSharingController(
        _ csc: UICloudSharingController,
        failedToSaveShareWithError error: any Error
    ) {
        show(error)
    }

    func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
        if let activeListID {
            try? repository.sharingDidChange(listID: activeListID, stopped: false)
        }
        changes.notify()
    }

    func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
        if let activeListID {
            try? repository.sharingDidChange(listID: activeListID, stopped: true)
        }
        changes.notify()
    }

    private func show(_ error: any Error) {
        guard let presenter = Self.presenter else { pendingError = error; return }
        let alert = UIAlertController(
            title: "iCloud Sharing",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        alert.view.tintColor = UIColor(Palette.accentText)
        presenter.present(alert, animated: true)
    }

    /// Shows a cold-launch invitation error once its scene becomes visible.
    func presentPendingError() {
        guard let pendingError, Self.presenter != nil else { return }
        self.pendingError = nil
        show(pendingError)
    }

    private static var presenter: UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive }
            ?? scenes.first { $0.activationState == .foregroundInactive }
        var controller = scene?.windows.first { $0.isKeyWindow }?.rootViewController
        while let next = controller?.presentedViewController {
            controller = next
        }
        return controller
    }
}
