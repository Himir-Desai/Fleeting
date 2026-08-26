import Core
import Foundation
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
        engine = DecayEngine()
        sweeper = ArchiveSweeper(repository: self.thoughts, engine: engine, clock: clock)
        intelligence = IntelligenceFactory.make()

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
        #endif
        await sweep()
        await refreshNudges()
    }

    #if DEBUG
        /// Launch argument that fills an empty store with thoughts at a spread of ages, for
        /// screenshots and for exercising decay by hand. Debug builds only.
        static let seedDemoArgument = "--seed-demo"

        /// One seeded thought, described by age and kind.
        private struct DemoThought {
            let body: String
            let age: Double
            let kind: ThoughtKind
            let streak: Int
            let sharpened: Bool

            init(
                _ body: String,
                age: Double,
                kind: ThoughtKind,
                streak: Int = 0,
                sharpened: Bool = false
            ) {
                self.body = body
                self.age = age
                self.kind = kind
                self.streak = streak
                self.sharpened = sharpened
            }
        }

        /// Fills in a finished interview, so the sharpened state is reachable without waiting
        /// for a model.
        /// - Parameters:
        ///   - thought: The idea to sharpen.
        ///   - date: When the interview happened.
        private static func attachDemoSharpening(to thought: inout Thought, at date: Date) {
            thought.beginSharpening(
                prompts: [
                    "Who reads this and actually changes what they use?",
                    "What is the hardest part of making it real?",
                    "What is the smallest thing you could do this week?"
                ],
                at: date
            )
            let answers = [
                "developers sick of every tool becoming a suite",
                "finding one genuinely good tool a week, forever",
                "write three issues and send them to ten people"
            ]
            for (question, answer) in zip(thought.sharpening?.questions ?? [], answers) {
                thought.answerSharpening(answer, to: question.id, at: date)
            }
            thought.attachWriteUp(
                WriteUp(
                    title: "A letter about tools that do one thing",
                    detail: """
                    A weekly letter about tools that do exactly one thing well. It is for \
                    developers sick of every tool becoming a suite. The hard part is finding one \
                    genuinely good tool a week, forever. The first thing to try is writing three \
                    issues and sending them to ten people.
                    """,
                    generatedAt: date
                ),
                at: date
            )
        }

        /// Inserts demo thoughts if asked and the store is empty.
        private func seedDemoDataIfRequested() async {
            guard ProcessInfo.processInfo.arguments.contains(Self.seedDemoArgument),
                  let existing = try? await thoughts.thoughts(in: .all), existing.isEmpty
            else { return }

            let now = clock.now
            let demo = [
                DemoThought("ship the decay engine before it decays", age: 0.2, kind: .todo),
                DemoThought(
                    "stretch every morning before coffee",
                    age: 1.5,
                    kind: .habit,
                    streak: 6
                ),
                DemoThought(
                    "newsletter about tools that do one thing",
                    age: 40,
                    kind: .idea,
                    sharpened: true
                ),
                DemoThought("pay the parking fine", age: 13, kind: .todo),
                DemoThought(
                    "learn to sail? or a boat-shaped midlife crisis",
                    age: 80,
                    kind: .idea
                )
            ]

            for entry in demo {
                let captured = now.addingTimeInterval(-entry.age * .day)
                var thought = Thought(
                    body: entry.body,
                    capturedAt: captured,
                    streak: entry.streak > 0
                        ? Streak(count: entry.streak, lastMarkedAt: captured)
                        : nil
                )
                thought.applyClassification(kind: entry.kind, title: nil)
                if entry.sharpened {
                    Self.attachDemoSharpening(to: &thought, at: captured)
                }
                try? await thoughts.add(thought)
            }
        }
    #endif

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

    /// Opens the on-disk store, degrading to memory rather than failing to launch.
    /// - Returns: The repository to use, whether it is the degraded in-memory one, and what it
    ///   can report about sharing and syncing.
    private static func openStore() -> Store {
        let reset = ProcessInfo.processInfo.arguments.contains(resetStoreArgument)
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
