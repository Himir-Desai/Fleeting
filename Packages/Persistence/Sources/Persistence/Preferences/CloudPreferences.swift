import Foundation

/// The small key-value store used to synchronize app preferences.
@MainActor
public protocol CloudPreferencesStore: AnyObject {
    func object(forKey key: String) -> Any?
    func set(_ value: Any?, forKey key: String)
    @discardableResult func synchronize() -> Bool
}

extension NSUbiquitousKeyValueStore: CloudPreferencesStore {}

/// Mirrors user preferences between local defaults and the signed-in iCloud account.
@MainActor
public final class CloudPreferences: NSObject {
    /// Permission grants and notification delivery history belong to each device.
    static let keys = [
        "sorting.preference",
        "decay.profiles",
        "fleeting.nudge.preferences",
        "capture.hintDismissed"
    ]
    private let defaults: UserDefaults
    private let cloud: any CloudPreferencesStore
    private let center: NotificationCenter
    private let onChange: () -> Void
    private var snapshot: [String: NSObject] = [:]

    /// Starts preference synchronization, preserving existing local choices on first use.
    public init(
        defaults: UserDefaults = .standard,
        cloud: any CloudPreferencesStore = NSUbiquitousKeyValueStore.default,
        center: NotificationCenter = .default,
        onChange: @escaping () -> Void
    ) {
        self.defaults = defaults
        self.cloud = cloud
        self.center = center
        self.onChange = onChange
        super.init()
        center.addObserver(
            self,
            selector: #selector(defaultsChanged),
            name: UserDefaults.didChangeNotification,
            object: defaults
        )
        center.addObserver(
            self,
            selector: #selector(remoteChanged(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloud
        )
        cloud.synchronize()
        for key in Self.keys {
            if let value = cloud.object(forKey: key) {
                defaults.set(value, forKey: key)
            } else if let value = defaults.object(forKey: key) {
                cloud.set(value, forKey: key)
            }
            snapshot[key] = defaults.object(forKey: key) as? NSObject
        }
        onChange()
    }

    /// Publishes only preferences actually edited on this device, avoiding echo writes.
    public func localChanged() {
        var changed = false
        for key in Self.keys {
            let value = defaults.object(forKey: key) as? NSObject
            guard value != snapshot[key] else { continue }
            snapshot[key] = value
            cloud.set(value, forKey: key)
            changed = true
        }
        if changed {
            onChange()
        }
    }

    @objc private nonisolated func defaultsChanged() {
        Task { @MainActor [weak self] in self?.localChanged() }
    }

    @objc private nonisolated func remoteChanged(_ notification: Notification) {
        guard let reason = notification.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int,
              reason != NSUbiquitousKeyValueStoreQuotaViolationChange else { return }
        let keys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? []
        Task { @MainActor [weak self] in self?.receive(keys: keys) }
    }

    /// Applies server changes without publishing them back as new local edits.
    func receive(keys: [String]) {
        for key in keys where Self.keys.contains(key) {
            let value = cloud.object(forKey: key) as? NSObject
            snapshot[key] = value
            if let value {
                defaults.set(value, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
        onChange()
    }

    deinit { center.removeObserver(self) }
}
