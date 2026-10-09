import Core
import CoreData
import Foundation

/// Relays imported cloud records and writes from other processes to feature observers.
public final class CloudStoreChanges {
    private let center: NotificationCenter
    private var observers: [NSObjectProtocol] = []

    /// Starts observing the persistent store without delaying capture.
    public init(changes: ThoughtChangeNotifier, center: NotificationCenter = .default) {
        self.center = center
        observers.append(center.addObserver(
            forName: .NSPersistentStoreRemoteChange, object: nil, queue: nil
        ) { _ in changes.notify() })
        observers.append(center.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil, queue: nil
        ) { notification in
            guard let event = notification
                .userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event,
                event.type == .import, event.endDate != nil, event.succeeded
            else { return }
            changes.notify()
        })
    }

    deinit {
        for observer in observers {
            center.removeObserver(observer)
        }
    }
}
