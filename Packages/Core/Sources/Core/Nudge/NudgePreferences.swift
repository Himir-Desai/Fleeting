import Foundation

/// When, and whether, the app is allowed to speak.
///
/// Deliberately small: ADR-0009 caps the app at three kinds of notification, so this cannot grow
/// into a settings screen of switches without a new decision.
public struct NudgePreferences: Equatable, Sendable, Codable {
    /// Whether one forgotten thought is resurfaced each day.
    public var dailyEnabled: Bool

    /// The hour of day, 0–23, the daily nudge arrives.
    public var dailyHour: Int

    /// Whether a weekly review invitation is sent.
    public var weeklyEnabled: Bool

    /// The weekday, 1 for Sunday through 7 for Saturday, the invitation arrives.
    public var weeklyWeekday: Int

    /// The hour of day, 0–23, the invitation arrives.
    public var weeklyHour: Int

    /// Whether a heads-up is sent before a thought archives.
    public var expiryWarningsEnabled: Bool

    /// Creates preferences.
    /// - Parameters:
    ///   - dailyEnabled: Whether the daily nudge is sent.
    ///   - dailyHour: Hour of day for the daily nudge, clamped to 0–23.
    ///   - weeklyEnabled: Whether the weekly invitation is sent.
    ///   - weeklyWeekday: Weekday for the invitation, clamped to 1–7.
    ///   - weeklyHour: Hour of day for the invitation, clamped to 0–23.
    ///   - expiryWarningsEnabled: Whether pre-archive warnings are sent.
    public init(
        dailyEnabled: Bool = true,
        dailyHour: Int = 19,
        weeklyEnabled: Bool = true,
        weeklyWeekday: Int = 1,
        weeklyHour: Int = 19,
        expiryWarningsEnabled: Bool = true
    ) {
        self.dailyEnabled = dailyEnabled
        self.dailyHour = min(max(dailyHour, 0), 23)
        self.weeklyEnabled = weeklyEnabled
        self.weeklyWeekday = min(max(weeklyWeekday, 1), 7)
        self.weeklyHour = min(max(weeklyHour, 0), 23)
        self.expiryWarningsEnabled = expiryWarningsEnabled
    }

    /// The defaults the app ships with: an evening nudge, a Sunday evening review.
    public static let standard = NudgePreferences()

    /// Preferences with everything switched off.
    public static let silent = NudgePreferences(
        dailyEnabled: false,
        weeklyEnabled: false,
        expiryWarningsEnabled: false
    )
}

/// Reads and writes the user's notification preferences.
public protocol NudgePreferencesStoring: Sendable {
    /// The stored preferences, or the defaults if none have been saved.
    func load() -> NudgePreferences

    /// Saves preferences.
    /// - Parameter preferences: What to store.
    func save(_ preferences: NudgePreferences)
}
