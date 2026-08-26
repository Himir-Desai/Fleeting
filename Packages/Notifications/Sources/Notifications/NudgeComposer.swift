import Core
import Foundation

/// Writes the copy for each kind of nudge, ahead of time.
///
/// Nothing here scolds or counts what the user has failed to do. A nudge exists to bring a thought
/// back, not to report on them.
public struct NudgeComposer: Sendable {
    private let nudges: NudgeSelector
    private let review: ReviewSelector
    private let engine: DecayEngine
    private let intelligence: any IntelligenceService
    private let times: NudgeClock

    /// Creates a composer.
    /// - Parameters:
    ///   - nudges: Chooses what is worth resurfacing.
    ///   - review: Counts what needs a decision, for the weekly invitation.
    ///   - engine: Works out when a thought would archive.
    ///   - intelligence: Writes the resurfacing line, when it can.
    ///   - times: Works out when each nudge should land.
    public init(
        nudges: NudgeSelector = NudgeSelector(),
        review: ReviewSelector = ReviewSelector(),
        engine: DecayEngine = DecayEngine(),
        intelligence: any IntelligenceService,
        times: NudgeClock = NudgeClock()
    ) {
        self.nudges = nudges
        self.review = review
        self.engine = engine
        self.intelligence = intelligence
        self.times = times
    }

    /// One forgotten thought, brought back in its own words.
    /// - Parameters:
    ///   - thoughts: Everything live.
    ///   - preferences: When the nudge should land.
    ///   - now: The instant to schedule from.
    ///   - recentlySurfaced: Identities to skip.
    /// - Returns: The nudge and the thought it surfaced, or `nil` if nothing qualifies.
    public func daily(
        from thoughts: [Thought],
        preferences: NudgePreferences,
        now: Date,
        recentlySurfaced: Set<Thought.ID>
    ) async -> (nudge: ScheduledNudge, surfaced: Thought.ID)? {
        guard preferences.dailyEnabled,
              let thought = nudges.forgotten(
                  from: thoughts, at: now, recentlySurfaced: recentlySurfaced
              ),
              let fireAt = times.nextDaily(hour: preferences.dailyHour, after: now)
        else { return nil }

        let line = await intelligence.resurfacingLine(for: thought.body)
        let nudge = ScheduledNudge(
            id: NudgeIdentifier.daily,
            kind: .dailyResurface,
            title: "You wrote this down",
            body: line ?? thought.body,
            fireAt: fireAt
        )
        return (nudge, thought.id)
    }

    /// An invitation to review, sent only when there is actually something to decide.
    /// - Parameters:
    ///   - thoughts: Everything live.
    ///   - preferences: When the invitation should land.
    ///   - now: The instant to schedule from.
    /// - Returns: The nudge, or `nil` when nothing needs a decision.
    public func weekly(
        from thoughts: [Thought],
        preferences: NudgePreferences,
        now: Date
    ) -> ScheduledNudge? {
        guard preferences.weeklyEnabled,
              let fireAt = times.nextWeekly(
                  weekday: preferences.weeklyWeekday, hour: preferences.weeklyHour, after: now
              )
        else { return nil }

        let waiting = review.count(from: thoughts, at: fireAt)
        guard waiting >= 1 else { return nil }

        return ScheduledNudge(
            id: NudgeIdentifier.weekly,
            kind: .weeklyReview,
            title: "A few decisions waiting",
            body: waiting == 1
                ? "One thought needs a decision."
                : "\(waiting) thoughts need a decision.",
            fireAt: fireAt
        )
    }

    /// A single heads-up about the thought closest to archiving.
    ///
    /// One, not one per thought: several warnings in a row would be exactly the nagging the app
    /// exists to avoid.
    /// - Parameters:
    ///   - thoughts: Everything live.
    ///   - preferences: Whether warnings are wanted.
    ///   - now: The instant to schedule from.
    /// - Returns: The nudge, or `nil` when nothing is close enough or the warning would be late.
    public func expiryWarning(
        from thoughts: [Thought],
        preferences: NudgePreferences,
        now: Date
    ) -> ScheduledNudge? {
        guard preferences.expiryWarningsEnabled,
              let soonest = nudges.expiringSoon(from: thoughts, at: now).first,
              let expiry = engine.expiryDate(of: soonest)
        else { return nil }

        // A day's notice where there is a day to give, and otherwise as much as remains.
        // Skipping the warning entirely for something expiring within the day would silence it
        // exactly when it matters most.
        let dayAhead = expiry.addingTimeInterval(-1 * .day)
        let fireAt = max(dayAhead, now.addingTimeInterval(3600))
        guard fireAt < expiry else { return nil }

        return ScheduledNudge(
            id: NudgeIdentifier.expiry,
            kind: .expiryWarning,
            title: "Archiving soon",
            body: Self.excerpt(of: soonest.body),
            fireAt: fireAt
        )
    }

    /// A short, unaltered piece of a captured note.
    /// - Parameter body: The raw captured text.
    /// - Returns: The text, shortened if long.
    private static func excerpt(of body: String) -> String {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count <= 100 ? trimmed : String(trimmed.prefix(97)) + "…"
    }
}
