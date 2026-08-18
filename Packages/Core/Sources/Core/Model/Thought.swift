import Foundation

/// A single captured thought — the app's only domain entity.
///
/// The raw text in ``body`` is never altered by the intelligence layer; generated material
/// lives in separate properties such as ``title``. Freshness is derived from ``lastActedAt``,
/// which advances only on deliberate action and never on mere viewing.
public struct Thought: Identifiable, Equatable, Sendable {
    /// Stable identity, assigned at capture and never reused.
    public let id: UUID

    /// The raw text exactly as it was typed. Mutable only through ``revise(body:at:)``.
    public private(set) var body: String

    /// A short generated title, or `nil` until the intelligence layer has produced one.
    public var title: String?

    /// What the thought turned out to be.
    public var kind: ThoughtKind

    /// Where the thought sits in its lifecycle.
    public var state: ThoughtState

    /// When the thought was first captured.
    public let capturedAt: Date

    /// When the thought was last deliberately acted on. Drives decay.
    public private(set) var lastActedAt: Date

    /// Creates a thought.
    /// - Parameters:
    ///   - id: Stable identity. Defaults to a fresh identifier.
    ///   - body: The raw text exactly as the user typed it.
    ///   - capturedAt: When the capture happened, read from a ``WallClock``.
    ///   - kind: What the thought is. Defaults to `.unsorted`, since classification is deferred.
    ///   - state: Lifecycle position. Defaults to `.inbox`.
    ///   - title: A generated title, if one already exists.
    public init(
        id: UUID = UUID(),
        body: String,
        capturedAt: Date,
        kind: ThoughtKind = .unsorted,
        state: ThoughtState = .inbox,
        title: String? = nil
    ) {
        self.id = id
        self.body = body
        self.capturedAt = capturedAt
        self.kind = kind
        self.state = state
        self.title = title
        lastActedAt = capturedAt
    }

    /// Replaces the captured text with a user-supplied revision, and counts as deliberate action.
    /// - Parameters:
    ///   - body: The new text.
    ///   - date: When the revision happened.
    public mutating func revise(body: String, at date: Date) {
        self.body = body
        markActed(at: date)
    }

    /// Records deliberate action on the thought, restoring its freshness.
    /// - Parameter date: When the action happened.
    public mutating func markActed(at date: Date) {
        lastActedAt = date
    }

    /// How long the thought has gone without deliberate action.
    /// - Parameter date: The instant to measure from.
    /// - Returns: The interval since ``lastActedAt``, never negative.
    public func timeSinceLastAction(at date: Date) -> TimeInterval {
        max(0, date.timeIntervalSince(lastActedAt))
    }
}
