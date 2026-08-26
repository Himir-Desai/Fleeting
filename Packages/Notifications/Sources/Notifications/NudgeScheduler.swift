import Core
import Foundation

/// Keeps the queued notifications in step with what is actually in the store.
///
/// Copy is written ahead of time and each nudge is queued as a single delivery rather than a
/// repeating one, because the model that writes the copy cannot run when a notification fires.
/// Re-running this on foreground and from a background refresh keeps the queue current.
public struct NudgeScheduler: Sendable {
    private let repository: any ThoughtRepository
    private let composer: NudgeComposer
    private let centre: any NotificationScheduling
    private let permissions: any NudgePermissions
    private let preferences: any NudgePreferencesStoring
    private let history: any NudgeHistoryStoring
    private let clock: any WallClock

    /// Creates a scheduler.
    /// - Parameters:
    ///   - repository: Where thoughts are read from.
    ///   - composer: Writes the copy.
    ///   - centre: Queues and cancels deliveries.
    ///   - permissions: Reports whether the app may speak at all.
    ///   - preferences: When, and whether, each kind is wanted.
    ///   - history: Remembers what was surfaced recently.
    ///   - clock: Time source for scheduling.
    public init(
        repository: any ThoughtRepository,
        composer: NudgeComposer,
        centre: any NotificationScheduling,
        permissions: any NudgePermissions,
        preferences: any NudgePreferencesStoring,
        history: any NudgeHistoryStoring,
        clock: any WallClock
    ) {
        self.repository = repository
        self.composer = composer
        self.centre = centre
        self.permissions = permissions
        self.preferences = preferences
        self.history = history
        self.clock = clock
    }

    /// Recomputes every permitted nudge and replaces what is queued.
    ///
    /// Without permission this cancels rather than schedules: a queue left behind after someone
    /// turned notifications off would be a promise the app had no right to keep.
    /// - Returns: What is now queued, for tests and for reporting in Settings.
    @discardableResult
    public func refresh() async -> [ScheduledNudge] {
        guard await permissions.authorization.permitsScheduling else {
            await centre.cancel(NudgeIdentifier.all)
            return []
        }

        let now = clock.now
        let wanted = preferences.load()
        let thoughts = await (try? repository.thoughts(in: .live)) ?? []

        var queued: [ScheduledNudge] = []

        if let daily = await composer.daily(
            from: thoughts,
            preferences: wanted,
            now: now,
            recentlySurfaced: history.recentlySurfaced()
        ) {
            queued.append(daily.nudge)
            history.recordSurfaced(daily.surfaced)
        }

        if let weekly = composer.weekly(from: thoughts, preferences: wanted, now: now) {
            queued.append(weekly)
        }

        if let expiry = composer.expiryWarning(from: thoughts, preferences: wanted, now: now) {
            queued.append(expiry)
        }

        // Replace wholesale: anything no longer wanted must actively go away.
        await centre.cancel(NudgeIdentifier.all)
        for nudge in queued {
            await centre.schedule(nudge)
        }

        return queued
    }

    /// Removes every nudge this app owns.
    public func cancelEverything() async {
        await centre.cancel(NudgeIdentifier.all)
    }
}
