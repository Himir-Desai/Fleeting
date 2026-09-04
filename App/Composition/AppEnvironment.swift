import Core
import Foundation
import Intelligence
import Notifications
import Persistence

/// The composition root: the single place where protocols are bound to concrete types.
///
/// Nothing below the app layer names an implementation, so swapping storage or intelligence
/// is a change to this file alone.
@MainActor
final class AppEnvironment {
    /// Launch argument that makes the app start from an empty store, used by the UI tests.
    static let resetStoreArgument = "--reset-store"

    /// The time source injected into everything that decays.
    let clock: any WallClock

    /// Storage for captured thoughts.
    let thoughts: any ThoughtRepository

    /// Computes freshness and decides what has expired.
    let engine: DecayEngine

    /// Moves expired thoughts into the archive.
    let sweeper: any ArchiveSweeping

    /// Sorts captured thoughts, on-device when possible and by rules otherwise.
    let intelligence: any IntelligenceService

    /// Announces stored-thought changes so open screens refresh themselves.
    let changes = ThoughtChangeNotifier()

    /// Reads and writes when the app is allowed to speak.
    let nudgePreferences: any NudgePreferencesStoring = UserDefaultsNudgePreferences()

    /// Reads and writes how the user wants thoughts sorted.
    let sortingPreference: any SortingPreferenceStoring = UserDefaultsSortingPreference()

    /// The decay rates in force, and the way to change them.
    ///
    /// A cache rather than a plain store because the engine consults the rates on every freshness
    /// calculation, and every screen shares one engine.
    let decayProfiles = DecayProfilesCache(store: UserDefaultsDecayProfiles())

    /// Asks for, and reports, permission to send notifications.
    let nudgePermissions: any NudgePermissions = SystemNotificationCentre()

    /// Keeps queued notifications in step with the store.
    let nudges: NudgeScheduler

    /// Whether the store lives in the shared container, and is therefore visible to widgets.
    let storageIsShared: Bool

    /// Reports whether thoughts are reaching iCloud.
    let sync: any SyncReporting

    /// Whether the on-disk store failed to open and captures are being held in memory only.
    ///
    /// Surfaced quietly inside the app rather than at launch: a storage problem must never
    /// stand between a cold launch and a focused field (ADR-0008).
    let storageIsDegraded: Bool

    /// Creates the environment.
    /// - Parameters:
    ///   - clock: Time source. Defaults to the system clock.
    ///   - thoughts: Thought storage. Defaults to the on-disk SwiftData store, falling back to
    ///     an in-memory store if it cannot be opened.
    init(clock: any WallClock = SystemClock(), thoughts: (any ThoughtRepository)? = nil) {
        self.clock = clock
        if let thoughts {
            self.thoughts = thoughts
            storageIsDegraded = false
            storageIsShared = false
            sync = LocalOnlySync()
        } else {
            let store = Self.openStore()
            self.thoughts = store.repository
            storageIsDegraded = store.degraded
            storageIsShared = store.isShared
            sync = store.sync
        }
        // The engine reads the rates afresh each time, so editing a lifetime in Settings applies
        // to the inbox, the sweeper and the review at once rather than after a relaunch.
        let profiles = decayProfiles
        engine = DecayEngine(profiles: { profiles.current })
        sweeper = ArchiveSweeper(repository: self.thoughts, engine: engine, clock: clock)

        // Read on every call, so choosing Rules only takes effect on the very next capture.
        let sorting = sortingPreference
        intelligence = PreferredIntelligence(
            automatic: IntelligenceFactory.make(),
            rules: IntelligenceFactory.rulesOnly(),
            preference: { sorting.load() }
        )

        let centre = SystemNotificationCentre()
        nudges = NudgeScheduler(
            repository: self.thoughts,
            composer: NudgeComposer(
                review: ReviewSelector(engine: engine),
                engine: engine,
                intelligence: intelligence
            ),
            centre: centre,
            permissions: centre,
            preferences: nudgePreferences,
            history: UserDefaultsNudgeHistory(),
            clock: clock
        )
    }

    /// Prepares the store after launch: seeds demo data when asked, then archives anything that
    /// expired while the app was closed.
    ///
    /// Runs after the capture field is on screen, never before it.
    func prepare() async {
        #if DEBUG
            await seedDemoDataIfRequested()
            await seedManyIfRequested()
        #endif
        await sweep()
        await refreshNudges()
        // Seeding and the sweep both happen after the home screen has already drawn, so anything
        // reading the store on appear — the habit strip especially — has to be told the store
        // moved underneath it (ADR-0047).
        changes.notify()
    }

    /// Archives anything that expired while the app was closed.
    ///
    /// Failures are ignored on purpose: a sweep that cannot run must never surface at launch or
    /// interfere with capture (ADR-0008). The next sweep will pick the work up.
    func sweep() async {
        _ = try? await sweeper.sweep()
    }

    /// Recomputes what the app has queued to say.
    ///
    /// Run after the field is on screen and after anything that changes the store, because copy is
    /// written ahead of time and goes stale as thoughts decay.
    func refreshNudges() async {
        await nudges.refresh()
    }

    /// What opening the store produced.
    private struct Store {
        let repository: any ThoughtRepository
        let degraded: Bool
        let isShared: Bool
        let sync: any SyncReporting
    }

    /// Preferences that describe what the user has already been shown.
    ///
    /// Cleared alongside the store so a UI test launching with `--reset-store` sees the app
    /// exactly as a new user would.
    private static let firstRunKeys = ["capture.hintDismissed"]

    /// Forgets what the user has been shown, so the next launch is a genuine first launch.
    private static func clearFirstRunState() {
        for key in firstRunKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    /// Opens the on-disk store, degrading to memory rather than failing to launch.
    /// - Returns: The repository to use, whether it is the degraded in-memory one, and what it
    ///   can report about sharing and syncing.
    private static func openStore() -> Store {
        let reset = ProcessInfo.processInfo.arguments.contains(resetStoreArgument)
        if reset {
            clearFirstRunState()
        }
        do {
            let opened = try ModelContainerFactory.store(resettingFirst: reset)
            return Store(
                repository: SwiftDataThoughtRepository(modelContainer: opened.container),
                degraded: false,
                isShared: opened.isShared,
                sync: CloudKitSyncReporter(attachment: opened.cloud)
            )
        } catch {
            return Store(
                repository: InMemoryThoughtRepository(),
                degraded: true,
                isShared: false,
                sync: LocalOnlySync(reason: .notAttached)
            )
        }
    }
}
