import Foundation
@testable import Persistence
import Testing

@MainActor
@Suite("iCloud preferences")
struct CloudPreferencesTests {
    private func defaults() -> UserDefaults {
        UserDefaults(suiteName: "cloud-preferences-tests.\(UUID())")!
    }

    @Test("existing cloud choices win on a second device and remote changes are not echoed")
    func remoteChoices() {
        let local = defaults()
        local.set("automatic", forKey: "sorting.preference")
        let cloud = MemoryCloudPreferences()
        cloud.values["sorting.preference"] = "rulesOnly"
        let bridge = CloudPreferences(
            defaults: local,
            cloud: cloud,
            center: NotificationCenter(),
            onChange: {}
        )
        #expect(local.string(forKey: "sorting.preference") == "rulesOnly")
        #expect(cloud.writes == 0)
        cloud.values["sorting.preference"] = "automatic"
        bridge.receive(keys: ["sorting.preference"])
        bridge.localChanged()
        #expect(local.string(forKey: "sorting.preference") == "automatic")
        #expect(cloud.writes == 0)
    }

    @Test("local choices migrate, offline edits publish, and device-only values stay local")
    func localChoices() {
        let local = defaults()
        local.set("rulesOnly", forKey: "sorting.preference")
        local.set("private", forKey: "notification.history")
        let cloud = MemoryCloudPreferences()
        let bridge = CloudPreferences(
            defaults: local,
            cloud: cloud,
            center: NotificationCenter(),
            onChange: {}
        )
        #expect(cloud.values["sorting.preference"] as? String == "rulesOnly")
        #expect(cloud.values["notification.history"] == nil)
        local.set("automatic", forKey: "sorting.preference")
        bridge.localChanged()
        #expect(cloud.values["sorting.preference"] as? String == "automatic")
        #expect(cloud.writes == 2)
    }

    @Test("remote removal restores defaults and reloads the decay cache")
    func remoteRemoval() {
        let local = defaults()
        let store = UserDefaultsDecayProfiles(defaults: local)
        let cache = DecayProfilesCache(store: store)
        let cloud = MemoryCloudPreferences()
        let bridge = CloudPreferences(defaults: local, cloud: cloud, center: NotificationCenter()) {
            cache.reload()
        }
        let custom = cache.current.setting(lifetime: 12345, for: .idea)
        cloud.values["decay.profiles"] = try? JSONEncoder().encode(custom)
        bridge.receive(keys: ["decay.profiles"])
        #expect(cache.current == custom)
        cloud.values["decay.profiles"] = nil
        bridge.receive(keys: ["decay.profiles"])
        #expect(cache.current == .standard)
        bridge.localChanged()
        #expect(cloud.writes == 0)
    }
}

@MainActor
private final class MemoryCloudPreferences: CloudPreferencesStore {
    var values: [String: Any] = [:]
    var writes = 0
    func object(forKey key: String) -> Any? {
        values[key]
    }

    func set(_ value: Any?, forKey key: String) {
        values[key] = value
        writes += 1
    }

    func synchronize() -> Bool {
        true
    }
}
