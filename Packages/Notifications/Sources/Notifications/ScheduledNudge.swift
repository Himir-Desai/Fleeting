import Core
import Foundation

/// One notification the app intends to deliver, with its copy already written.
///
/// Copy is composed ahead of time rather than at delivery, because the on-device model cannot run
/// when a notification fires.
public struct ScheduledNudge: Equatable, Sendable {
    /// Stable identity, so a nudge can be replaced rather than duplicated.
    public let id: String

    /// Which of the three permitted kinds this is.
    public let kind: NudgeKind

    /// The notification title.
    public let title: String

    /// The notification body.
    public let body: String

    /// When it should arrive.
    public let fireAt: Date

    /// Creates a nudge.
    /// - Parameters:
    ///   - id: Stable identity.
    ///   - kind: Which permitted kind it is.
    ///   - title: The title.
    ///   - body: The body.
    ///   - fireAt: When it should arrive.
    public init(id: String, kind: NudgeKind, title: String, body: String, fireAt: Date) {
        self.id = id
        self.kind = kind
        self.title = title
        self.body = body
        self.fireAt = fireAt
    }
}

/// Delivers notifications, and reports what is already queued.
///
/// A protocol so the scheduling rules can be tested without the system notification centre.
public protocol NotificationScheduling: Sendable {
    /// Identifiers of nudges already queued.
    func pendingIdentifiers() async -> Set<String>

    /// Queues a nudge, replacing any with the same identity.
    /// - Parameter nudge: What to deliver, and when.
    func schedule(_ nudge: ScheduledNudge) async

    /// Removes queued nudges.
    /// - Parameter identifiers: What to remove.
    func cancel(_ identifiers: Set<String>) async
}
