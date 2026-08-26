import Foundation

/// The identifiers this app owns.
///
/// Namespaced so cancelling the app's own nudges can never disturb anything else queued for the
/// user, and so a stale nudge is replaced rather than duplicated.
enum NudgeIdentifier {
    /// The daily resurfacing nudge.
    static let daily = "fleeting.nudge.daily"

    /// The weekly review invitation.
    static let weekly = "fleeting.nudge.weekly"

    /// The single pre-archive warning.
    static let expiry = "fleeting.nudge.expiry"

    /// Every identifier the app manages.
    static let all: Set<String> = [daily, weekly, expiry]
}
