import Foundation

/// A single captured thought — the app's only domain entity.
///
/// The raw text in ``body`` is never altered by the intelligence layer; generated material
/// lives in separate properties such as ``title``. Freshness is derived from ``lastActedAt``,
/// which advances only on deliberate action and never on mere viewing.
public struct Thought: Identifiable, Equatable, Hashable, Sendable {
    /// Stable identity, assigned at capture and never reused.
    public let id: UUID

    /// The raw text exactly as it was typed. Mutable only through ``revise(body:at:)``.
    public private(set) var body: String

    /// A short generated title, or `nil` until the intelligence layer has produced one.
    public var title: String?

    /// What the thought turned out to be.
    public private(set) var kind: ThoughtKind

    /// Where ``kind`` came from. A confirmed kind is never overwritten by classification.
    public private(set) var kindSource: KindSource

    /// When a todo is due, if a date has been set. Meaningless for other kinds.
    public var dueAt: Date?

    /// The run of consecutive periods a habit has been kept. `nil` until first marked.
    public private(set) var streak: Streak?

    /// How often a habit is meant to be kept. Meaningless for other kinds.
    ///
    /// Inferred from the wording at classification time and editable on the thought's own page,
    /// which is where a decision about a thought belongs (ADR-0048).
    public private(set) var cadence: HabitCadence

    /// Where ``cadence`` came from. A confirmed cadence is never overwritten by classification.
    ///
    /// Reuses ``KindSource`` rather than declaring a parallel type: the question is identical —
    /// did nobody say, did the app guess, or did a person decide — and two enums with the same
    /// three cases would drift.
    public private(set) var cadenceSource: KindSource

    /// The interview and write-up for an idea, or `nil` if it has never been sharpened.
    public internal(set) var sharpening: Sharpening?

    /// How many times the thought has been set aside.
    ///
    /// Repeatedly snoozing something is itself a signal: it is the shape of a decision being
    /// avoided, which is exactly what the weekly review exists to surface.
    public private(set) var snoozeCount: Int

    /// Where the thought sits in its lifecycle.
    public var state: ThoughtState

    /// When the thought was first captured.
    public let capturedAt: Date

    /// When the thought was last deliberately acted on. Drives decay.
    public private(set) var lastActedAt: Date

    /// A lifetime chosen at capture that overrides the kind's decay rate, in seconds, or `nil` to
    /// decay at the kind's normal rate.
    ///
    /// Set once when the thought is written and never changed by classification, so choosing "keep
    /// this for three months" survives the app deciding what the thought is.
    public private(set) var customLifetime: TimeInterval?

    /// Creates a thought.
    /// - Parameters:
    ///   - id: Stable identity. Defaults to a fresh identifier.
    ///   - body: The raw text exactly as the user typed it.
    ///   - capturedAt: When the capture happened, read from a ``WallClock``.
    ///   - kind: What the thought is. Defaults to `.unsorted`, since classification is deferred.
    ///   - state: Lifecycle position. Defaults to `.inbox`.
    ///   - title: A generated title, if one already exists.
    ///   - lastActedAt: When the thought was last acted on. Defaults to `capturedAt`, which is
    ///     correct for a new capture; storage passes the stored value to reconstitute a thought.
    ///   - kindSource: Where the kind came from. Defaults to unclassified.
    ///   - dueAt: When a todo is due, if set.
    ///   - streak: A habit's run of consecutive periods, if any.
    ///   - cadence: How often a habit is meant to be kept. Defaults to daily.
    ///   - cadenceSource: Where the cadence came from. Defaults to unclassified.
    ///   - sharpening: An interview already in progress or finished, if any.
    ///   - snoozeCount: How many times it has already been set aside.
    ///   - customLifetime: A capture-time lifetime override, in seconds, or `nil` to decay at the
    ///     kind's rate.
    public init(
        id: UUID = UUID(),
        body: String,
        capturedAt: Date,
        kind: ThoughtKind = .unsorted,
        state: ThoughtState = .inbox,
        title: String? = nil,
        lastActedAt: Date? = nil,
        kindSource: KindSource = .unclassified,
        dueAt: Date? = nil,
        streak: Streak? = nil,
        cadence: HabitCadence = .default,
        cadenceSource: KindSource = .unclassified,
        sharpening: Sharpening? = nil,
        snoozeCount: Int = 0,
        customLifetime: TimeInterval? = nil
    ) {
        self.id = id
        self.body = body
        self.title = title
        self.kind = kind
        self.kindSource = kindSource
        self.dueAt = dueAt
        self.streak = streak
        self.cadence = cadence
        self.cadenceSource = cadenceSource
        self.sharpening = sharpening
        self.snoozeCount = max(snoozeCount, 0)
        self.state = state
        self.capturedAt = capturedAt
        self.lastActedAt = lastActedAt ?? capturedAt
        self.customLifetime = customLifetime.map { max($0, 0) }
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

    /// Applies a classifier's guess at what the thought is.
    ///
    /// Ignored once a person has confirmed the kind, so re-running classification can never undo a
    /// correction. Does not count as deliberate action: the app noticing something is not the user
    /// attending to it, and it must not reset decay.
    /// - Parameters:
    ///   - kind: The inferred kind.
    ///   - title: A generated short title, if one was produced. Never replaces ``body``.
    public mutating func applyClassification(kind: ThoughtKind, title: String?) {
        guard kindSource != .confirmed else { return }
        self.kind = kind
        kindSource = .inferred
        if let title, !title.isEmpty {
            self.title = title
        }
    }

    /// Records a person's decision about what the thought is.
    ///
    /// Counts as deliberate action, and permanently protects the kind from classification.
    /// - Parameters:
    ///   - kind: The kind the user chose.
    ///   - date: When they chose it.
    public mutating func confirmKind(_ kind: ThoughtKind, at date: Date) {
        self.kind = kind
        kindSource = .confirmed
        markActed(at: date)
    }

    /// Replaces the capture-time lifetime override, or clears it to decay at the kind's rate.
    ///
    /// Not deliberate action: changing how long a thought is allowed to last is a setting, not
    /// attending to the thought itself, so it does not reset freshness.
    /// - Parameter seconds: The new lifetime in seconds, or `nil` to follow the kind.
    public mutating func setCustomLifetime(_ seconds: TimeInterval?) {
        customLifetime = seconds.map { max($0, 0) }
    }

    /// Marks a todo complete.
    /// - Parameter date: When it was completed.
    public mutating func complete(at date: Date) {
        state = .done(at: date)
    }

    /// Records a habit as kept for this period, extending or restarting its streak.
    /// - Parameter date: When the habit was marked done.
    public mutating func markHabitKept(at date: Date) {
        var updated = streak ?? Streak()
        updated.mark(at: date, cadence: cadence)
        streak = updated
        markActed(at: date)
    }

    /// Whether this habit is waiting to be kept.
    ///
    /// A habit already kept within its current period is not due, which is what takes it off the
    /// home screen the moment it is marked (ADR-0048). Only habits are ever due.
    /// - Parameter date: The instant being asked about.
    /// - Returns: `true` when the habit still needs this period's mark.
    public func isDue(at date: Date) -> Bool {
        guard kind == .habit else { return false }
        guard let streak else { return true }
        return !streak.isKept(at: date, cadence: cadence)
    }

    /// Replaces how often a habit is meant to be kept, and remembers that a person chose it.
    ///
    /// Not deliberate action on the thought: choosing a cadence is a setting about the habit, not
    /// an instance of keeping it, so it must not restore freshness or touch the run.
    /// - Parameter cadence: The new cadence.
    public mutating func setCadence(_ cadence: HabitCadence) {
        self.cadence = cadence
        cadenceSource = .confirmed
    }

    /// Applies a cadence the classifier read out of the wording.
    ///
    /// Ignored once a person has chosen one by hand, on the same reasoning as
    /// ``applyClassification(kind:title:)``: the app noticing something must never overwrite a
    /// decision someone made.
    /// - Parameter cadence: The inferred cadence.
    public mutating func applyInferredCadence(_ cadence: HabitCadence) {
        guard cadenceSource != .confirmed else { return }
        self.cadence = cadence
        cadenceSource = .inferred
    }

    /// Takes back the most recent habit mark.
    ///
    /// Freshness is deliberately left where marking put it. Undoing an accidental tap should not
    /// also age the thought, and the alternative — restoring the previous `lastActedAt` — would
    /// need a history this model does not keep (ADR-0044).
    /// - Parameter previous: When the habit was marked before the one being undone, if known.
    public mutating func undoHabitKept(previous: Date? = nil) {
        guard var updated = streak else { return }
        updated.unmark(previous: previous)
        streak = updated.hasStarted ? updated : nil
    }

    /// Sets the thought aside until a chosen date, which counts as deliberate action.
    ///
    /// A snoozed thought is held at full freshness until the snooze ends, so setting something
    /// aside buys real time rather than only hiding it.
    /// - Parameters:
    ///   - date: When the thought should return to the inbox.
    ///   - now: When the snooze was requested.
    public mutating func snooze(until date: Date, at now: Date) {
        state = .snoozed(until: date)
        snoozeCount += 1
        markActed(at: now)
    }

    /// Moves the thought to the archive.
    ///
    /// Used both by expiry and by an explicit human archive. Does not count as deliberate action:
    /// archiving is the end of a thought's active life, not attention paid to it.
    /// - Parameter date: When the thought was archived.
    public mutating func archive(at date: Date) {
        state = .archived(at: date)
    }

    /// Returns an archived thought to the inbox at full freshness.
    /// - Parameter date: When the thought was restored.
    public mutating func restore(at date: Date) {
        state = .inbox
        markActed(at: date)
    }

    /// Hashes on identity alone.
    ///
    /// Two thoughts are equal only when every field matches, but a thought's identity never
    /// changes, so hashing on it keeps navigation stable while a thought is being edited.
    /// - Parameter hasher: The hasher to feed.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    /// How long the thought has gone without deliberate action.
    /// - Parameter date: The instant to measure from.
    /// - Returns: The interval since ``lastActedAt``, never negative.
    public func timeSinceLastAction(at date: Date) -> TimeInterval {
        max(0, date.timeIntervalSince(lastActedAt))
    }

    /// Whether the thought is asking for attention right now.
    ///
    /// Live and not inside a running snooze. This, not ``ThoughtState/isLive``, is the question
    /// every surface that shows thoughts to a person should ask.
    /// - Parameter date: The instant to judge at.
    /// - Returns: `true` when the thought is in play right now.
    public func isAwake(at date: Date) -> Bool {
        state.isAwake(at: date)
    }
}
