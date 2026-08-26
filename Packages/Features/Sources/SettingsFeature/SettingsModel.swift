import Core
import Foundation
import Observation

/// State for the settings screen.
@MainActor
@Observable
public final class SettingsModel {
    /// What is currently sorting captured thoughts, or `nil` until asked.
    public private(set) var availability: IntelligenceAvailability?

    /// Whether the app is currently permitted to send notifications.
    public private(set) var authorization: NudgeAuthorization = .notAsked

    /// When, and whether, the app may speak.
    public private(set) var preferences: NudgePreferences

    /// The decay rates in force, one per kind.
    public let profiles: DecayProfiles

    /// Whether the store is shared with the widgets.
    public let storageIsShared: Bool

    /// Whether the on-disk store failed to open and thoughts are being held in memory only.
    public let storageIsDegraded: Bool

    /// Whether thoughts are reaching iCloud, or `.checking` until asked.
    public private(set) var syncStatus: SyncStatus = .checking

    private let intelligence: any IntelligenceService
    private let sync: any SyncReporting
    private let store: any NudgePreferencesStoring
    private let permissions: any NudgePermissions
    private let onNudgesChanged: @Sendable () async -> Void

    /// Creates the settings screen's state.
    /// - Parameters:
    ///   - intelligence: Asked what is currently answering.
    ///   - profiles: The decay rates to display.
    ///   - storageIsShared: Whether widgets can read the store.
    ///   - storageIsDegraded: Whether the on-disk store failed to open.
    ///   - sync: Asked whether thoughts are reaching iCloud.
    ///   - store: Where notification preferences are kept.
    ///   - permissions: Asks for, and reports, notification permission.
    ///   - onNudgesChanged: Called whenever something changes what should be queued.
    public init(
        intelligence: any IntelligenceService,
        profiles: DecayProfiles,
        storageIsShared: Bool = true,
        storageIsDegraded: Bool = false,
        sync: any SyncReporting = LocalOnlySync(),
        store: any NudgePreferencesStoring,
        permissions: any NudgePermissions,
        onNudgesChanged: @escaping @Sendable () async -> Void
    ) {
        self.intelligence = intelligence
        self.profiles = profiles
        self.storageIsShared = storageIsShared
        self.storageIsDegraded = storageIsDegraded
        self.sync = sync
        self.store = store
        self.permissions = permissions
        self.onNudgesChanged = onNudgesChanged
        preferences = store.load()
    }

    /// Reads the current state of everything shown.
    public func load() async {
        availability = await intelligence.availability
        authorization = await permissions.authorization
        syncStatus = await sync.status
        preferences = store.load()
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

    /// How the current intelligence state should be described to the user.
    /// - Returns: A headline and a supporting sentence.
    public var status: (headline: String, detail: String) {
        switch availability {
        case .onDevice:
            ("On-device model", "Sorting happens on this iPhone. Nothing is sent anywhere.")
        case let .heuristic(reason):
            ("Rules", reason.summary + " Sorting still works, it is just simpler.")
        case nil:
            ("Checking…", "")
        }
    }

    /// How notification permission should be described.
    /// - Returns: A headline and a supporting sentence.
    public var notificationStatus: (headline: String, detail: String) {
        switch authorization {
        case .notAsked:
            ("Off", "Fleeting can resurface a forgotten thought once a day. It never asks twice.")
        case .allowed:
            ("On", "At most one nudge a day, plus a weekly invitation to review.")
        case .denied:
            ("Off", "Notifications are turned off for Fleeting in the Settings app.")
        }
    }

    /// How storage itself should be described.
    ///
    /// Reported here rather than at launch, where an alert would be the one thing ADR-0008
    /// forbids — but reported, because a store that never opened will lose thoughts when the
    /// app closes, and silence about that would be worse than the fault.
    /// - Returns: A headline and a supporting sentence.
    public var storageDescription: (headline: String, detail: String) {
        storageIsDegraded
            ? (
                "Holding thoughts in memory",
                """
                Fleeting could not open its database, so anything captured now is lost when the \
                app closes. Restarting usually fixes it.
                """
            )
            : ("On this device", "Thoughts are written to disk as soon as you save them.")
    }

    /// How syncing should be described.
    /// - Returns: A headline and a supporting sentence.
    public var syncDescription: (headline: String, detail: String) {
        switch syncStatus {
        case .syncing:
            ("iCloud", "Thoughts follow you to your other devices. Nothing else sees them.")
        case .signedOut:
            (
                "This iPhone only",
                "Sign in to iCloud to keep thoughts in step across devices. Capture works either way."
            )
        case let .localOnly(reason):
            ("This iPhone only", reason.summary + " Capture works either way.")
        case .checking:
            ("Checking…", "")
        }
    }

    /// How the widgets' access to the store should be described.
    /// - Returns: A headline and a supporting sentence.
    public var widgetStatus: (headline: String, detail: String) {
        storageIsShared
            ? ("Sharing", "Widgets read the same thoughts the app does.")
            : (
                "Not shared",
                "This build has no App Group, so widgets will look empty. The app itself is fine."
            )
    }

    /// How long each kind of thought lasts before archiving.
    /// - Returns: A label and a day count per kind, in the order shown.
    public var lifetimes: [(kind: ThoughtKind, days: Int)] {
        ThoughtKind.allCases.map { kind in
            (kind, Int(profiles.policy(for: kind).lifetime / .day))
        }
    }
}
