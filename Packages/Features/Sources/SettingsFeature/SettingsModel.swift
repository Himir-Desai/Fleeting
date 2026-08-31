import Core
import Foundation
import Observation

/// State for the settings screen.
///
/// Settings is where the app's behaviour is *changed*, so everything here is either a control or
/// the truth about something the user cannot change but would be misled by not knowing
/// (ADR-0032). Pure status with no action behind it belongs in About, not in its own section.
@MainActor
@Observable
public final class SettingsModel {
    /// What is currently sorting captured thoughts, or `nil` until asked.
    public private(set) var availability: IntelligenceAvailability?

    /// How the user has asked for thoughts to be sorted.
    public private(set) var sorting: SortingPreference

    /// Whether the app is currently permitted to send notifications.
    public private(set) var authorization: NudgeAuthorization = .notAsked

    /// When, and whether, the app may speak.
    public private(set) var preferences: NudgePreferences

    /// The decay rates in force, one per kind.
    public private(set) var profiles: DecayProfiles

    /// Whether the store is shared with the widgets.
    public let storageIsShared: Bool

    /// Whether the on-disk store failed to open and thoughts are being held in memory only.
    public let storageIsDegraded: Bool

    /// Whether thoughts are reaching iCloud, or `.checking` until asked.
    public private(set) var syncStatus: SyncStatus = .checking

    private let intelligence: any IntelligenceService
    private let sync: any SyncReporting
    private let store: any NudgePreferencesStoring
    private let sortingStore: any SortingPreferenceStoring
    private let decayStore: any DecayProfilesStoring
    private let permissions: any NudgePermissions
    private let onNudgesChanged: @Sendable () async -> Void

    /// Creates the settings screen's state.
    /// - Parameters:
    ///   - intelligence: Asked what is currently answering.
    ///   - sortingStore: Reads and writes how the user wants thoughts sorted.
    ///   - decayStore: Reads and writes how long each kind lasts.
    ///   - storageIsShared: Whether widgets can read the store.
    ///   - storageIsDegraded: Whether the on-disk store failed to open.
    ///   - sync: Asked whether thoughts are reaching iCloud.
    ///   - store: Where notification preferences are kept.
    ///   - permissions: Asks for, and reports, notification permission.
    ///   - onNudgesChanged: Called whenever something changes what should be queued.
    public init(
        intelligence: any IntelligenceService,
        sortingStore: any SortingPreferenceStoring,
        decayStore: any DecayProfilesStoring,
        storageIsShared: Bool = true,
        storageIsDegraded: Bool = false,
        sync: any SyncReporting = LocalOnlySync(),
        store: any NudgePreferencesStoring,
        permissions: any NudgePermissions,
        onNudgesChanged: @escaping @Sendable () async -> Void
    ) {
        self.intelligence = intelligence
        self.sortingStore = sortingStore
        self.decayStore = decayStore
        self.storageIsShared = storageIsShared
        self.storageIsDegraded = storageIsDegraded
        self.sync = sync
        self.store = store
        self.permissions = permissions
        self.onNudgesChanged = onNudgesChanged
        preferences = store.load()
        sorting = sortingStore.load()
        profiles = decayStore.load()
    }

    /// Reads the current state of everything shown.
    public func load() async {
        availability = await intelligence.availability
        authorization = await permissions.authorization
        syncStatus = await sync.status
        preferences = store.load()
        sorting = sortingStore.load()
        profiles = decayStore.load()
    }

    /// Asks the user for permission to send notifications.
    ///
    /// Reached only from this screen, never at launch: nothing may stand between a cold launch and
    /// a focused capture field (ADR-0008).
    public func requestPermission() async {
        authorization = await permissions.request()
        await onNudgesChanged()
    }

    /// Whether the notification switches should be offered at all.
    public var canConfigureNudges: Bool {
        authorization == .allowed
    }

    /// Saves a change to what the app is allowed to say.
    /// - Parameter change: Applied to the current preferences.
    public func update(_ change: (inout NudgePreferences) -> Void) async {
        var updated = preferences
        change(&updated)
        preferences = updated
        store.save(updated)
        await onNudgesChanged()
    }

    /// Records how the user wants thoughts sorted, and re-reads what will now answer.
    /// - Parameter preference: The choice made.
    public func chooseSorting(_ preference: SortingPreference) async {
        guard preference != sorting else { return }
        sorting = preference
        sortingStore.save(preference)
        availability = await intelligence.availability
    }

    /// Sets how long a kind of thought lasts before it archives.
    ///
    /// Applied immediately: the rates are read live, so the inbox behind this screen is already
    /// showing the new freshness by the time the user goes back.
    /// - Parameters:
    ///   - days: The new lifetime in days.
    ///   - kind: The kind being changed.
    public func setLifetime(days: Int, for kind: ThoughtKind) {
        let updated = profiles.setting(lifetime: Double(max(days, 1)) * .day, for: kind)
        guard updated != profiles else { return }
        profiles = updated
        // Saved through the shared cache, so the inbox behind this screen is already using the
        // new rate by the time the user goes back.
        decayStore.save(updated)
    }

    /// Restores the decay rates the app ships with.
    public func resetLifetimes() {
        guard profiles != .standard else { return }
        profiles = .standard
        decayStore.save(.standard)
    }

    /// Whether the rates have been changed from the ones the app ships with.
    public var lifetimesAreCustom: Bool {
        !profiles.isStandard
    }

    /// What is actually answering, described honestly beneath the choice.
    ///
    /// The choice is the control; this is what that choice is currently getting you, which is not
    /// always the same thing — asking for the model on a device that has none still gets rules.
    public var sortingReality: String {
        switch availability {
        case .onDevice:
            "Sorting on this iPhone's model. Nothing is sent anywhere."
        case let .heuristic(reason) where reason == .userChose:
            "Sorting by rules, as you asked."
        case let .heuristic(reason):
            reason.summary + " Sorting still works, it is just simpler."
        case nil:
            "Checking…"
        }
    }

    /// How long each kind of thought lasts before archiving.
    /// - Returns: A label and a day count per kind, in the order shown.
    public var lifetimes: [(kind: ThoughtKind, days: Int)] {
        ThoughtKind.allCases.map { kind in
            (kind, Int(profiles.policy(for: kind).lifetime / .day))
        }
    }

    /// One unchangeable fact about where thoughts live.
    public struct Fact: Identifiable, Sendable {
        /// What the fact is about.
        public let label: String
        /// The current answer.
        public let value: String
        /// Whether the answer is one the user would want to know is not the happy case.
        public let isWarning: Bool

        public var id: String {
            label
        }
    }

    /// The facts about where thoughts live, as one line each.
    ///
    /// None of these is a setting: storage, syncing and widget sharing are all decided by the
    /// device and the signing account. They are reported because a user whose thoughts are not
    /// syncing needs to know, and grouped under About because there is nothing to press.
    public var facts: [Fact] {
        var rows = [
            Fact(
                label: "Storage",
                value: storageIsDegraded ? "In memory only" : "On this device",
                isWarning: storageIsDegraded
            )
        ]

        switch syncStatus {
        case .syncing:
            rows.append(Fact(label: "Syncing", value: "iCloud", isWarning: false))
        case .signedOut, .localOnly:
            rows.append(Fact(label: "Syncing", value: "This iPhone only", isWarning: true))
        case .checking:
            rows.append(Fact(label: "Syncing", value: "Checking…", isWarning: false))
        }

        rows.append(
            Fact(
                label: "Widgets",
                value: storageIsShared ? "Sharing" : "Not shared",
                isWarning: !storageIsShared
            )
        )
        return rows
    }

    /// The one thing in About that the user may need to act on, if anything.
    ///
    /// Storage failing loses thoughts, so it is said plainly rather than left as a quiet row.
    public var warning: String? {
        if storageIsDegraded {
            return """
            Fleeting could not open its database, so anything captured now is lost when the app \
            closes. Restarting usually fixes it.
            """
        }
        if case .signedOut = syncStatus {
            return "Sign in to iCloud to keep thoughts in step across devices. Capture works either way."
        }
        return nil
    }
}
