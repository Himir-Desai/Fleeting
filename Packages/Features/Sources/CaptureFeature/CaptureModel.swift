import Core
import Foundation
import Observation

/// The capture screen's state and rules.
///
/// A reference type because it outlives a single render pass and does async work: a save
/// suspends, and the view, the in-flight task, and any future ambient surface must all observe
/// the same instance.
@MainActor
@Observable
public final class CaptureModel {
    /// The text currently in the field. Bound directly to the capture field.
    public var text: String = ""

    /// A kind the user chose in advanced options before saving, or `nil` to let the app sort it.
    ///
    /// When set, the saved thought is created with that kind already confirmed, so classification
    /// leaves it alone. Cleared after each save, so every capture starts from "let the app sort".
    /// Set through ``chooseKind(_:)``, which also moves the expiry wheels.
    public private(set) var chosenKind: ThoughtKind?

    /// Whether the next capture applies the wheels' lifetime instead of its type's normal rate.
    ///
    /// Not a visible control: it turns on when a person picks a specific type or spins the wheels,
    /// and stays off for an untouched automatic capture so classification still governs decay.
    public private(set) var usesCustomExpiration = false

    /// How many ``expirationUnit`` the next capture should last.
    ///
    /// The wheels show this whenever advanced options are open. It defaults to the selected type's
    /// natural period and is reset after each save.
    public private(set) var expirationCount = 1

    /// The unit the ``expirationCount`` is measured in.
    public private(set) var expirationUnit: ExpirationUnit = .months

    /// The chosen lifetime in seconds, or `nil` to let the thought decay at its kind's rate.
    var customLifetime: TimeInterval? {
        guard usesCustomExpiration else { return nil }
        return TimeInterval(max(expirationCount, 1)) * expirationUnit.seconds
    }

    /// Picks a type by hand — or `nil` for automatic — and moves the expiry wheels to that type's
    /// natural period.
    ///
    /// A specific type turns on the custom lifetime, because picking one is an explicit decision;
    /// automatic turns it back off, so the app still decides both kind and timing.
    /// - Parameter kind: The chosen type, or `nil` for automatic sorting.
    public func chooseKind(_ kind: ThoughtKind?) {
        chosenKind = kind
        let expiry = Self.defaultExpiry(for: kind)
        expirationCount = expiry.count
        expirationUnit = expiry.unit
        usesCustomExpiration = kind != nil
    }

    /// Records a deliberate spin of the number wheel, which commits to a custom lifetime.
    /// - Parameter count: The new amount.
    public func setExpirationCount(_ count: Int) {
        expirationCount = count
        usesCustomExpiration = true
    }

    /// Records a deliberate spin of the unit wheel, which commits to a custom lifetime.
    /// - Parameter unit: The new unit.
    public func setExpirationUnit(_ unit: ExpirationUnit) {
        expirationUnit = unit
        usesCustomExpiration = true
    }

    /// The lifetime the wheels show for a given type, mirroring the shipping decay profiles.
    /// - Parameter kind: The type, or `nil` for automatic (the unsorted period).
    /// - Returns: The number and unit to display.
    static func defaultExpiry(for kind: ThoughtKind?) -> (count: Int, unit: ExpirationUnit) {
        switch kind {
        case .none, .unsorted: (1, .months)
        case .idea: (3, .months)
        case .todo: (2, .weeks)
        case .habit: (1, .weeks)
        }
    }

    /// Whether a save is in flight. Never disables the field — typing must never wait on a write.
    public private(set) var isSaving = false

    /// The most recent save failure, or `nil` if the last attempt succeeded.
    public private(set) var lastError: (any Error)?

    /// How many thoughts this screen has committed. Drives the save haptic.
    ///
    /// A count rather than a flag: two saves in a row have to read as two distinct events.
    public private(set) var savedCount = 0

    /// How many saves have failed. Drives the failure haptic.
    public private(set) var failedCount = 0

    /// The classification started by the most recent save.
    ///
    /// Exposed so tests can await work that is deliberately not awaited in production.
    public private(set) var classificationTask: Task<Void, Never>?

    private let repository: any ThoughtRepository
    private let intelligence: any IntelligenceService
    private let changes: ThoughtChangeNotifier
    private let clock: any WallClock

    /// Creates the capture screen's state.
    /// - Parameters:
    ///   - repository: Where committed thoughts are stored.
    ///   - intelligence: Sorts a thought after it has been stored, never before.
    ///   - changes: Told when a thought is stored or sorted, so open screens can refresh.
    ///   - clock: Time source used to stamp the capture.
    public init(
        repository: any ThoughtRepository,
        intelligence: any IntelligenceService,
        changes: ThoughtChangeNotifier = ThoughtChangeNotifier(),
        clock: any WallClock
    ) {
        self.repository = repository
        self.intelligence = intelligence
        self.changes = changes
        self.clock = clock
    }

    /// Whether the current text is worth committing.
    ///
    /// Whitespace alone is not a thought, so it never reaches storage.
    public var canSave: Bool {
        !trimmedText.isEmpty
    }

    /// Commits the current text as a new thought.
    ///
    /// Clears the field only after the write succeeds: if storage fails the text stays exactly
    /// where it is, because losing a thought the user already typed is the worst outcome this
    /// screen can produce. Does nothing when there is nothing to save or a save is already
    /// running.
    public func save() async {
        guard canSave, !isSaving else { return }

        let picked = chosenKind
        let thought = Thought(
            body: trimmedText,
            capturedAt: clock.now,
            kind: picked ?? .unsorted,
            kindSource: picked == nil ? .unclassified : .confirmed,
            customLifetime: customLifetime
        )
        isSaving = true
        defer { isSaving = false }

        do {
            try await repository.add(thought)
            text = ""
            chosenKind = nil
            usesCustomExpiration = false
            expirationCount = 1
            expirationUnit = .months
            lastError = nil
            savedCount += 1
            changes.notify()
            // A kind the user chose is already confirmed, so classification would only be
            // ignored; only an unsorted capture is worth sorting in the background.
            if picked == nil {
                classifyInBackground(thought)
            }
        } catch {
            lastError = error
            failedCount += 1
        }
    }

    /// Sorts a stored thought without making anyone wait for it.
    ///
    /// Deliberately not awaited: classification must never sit between the user and their next
    /// thought, and a thought that is never classified is merely unsorted, which is a valid state.
    /// - Parameter thought: The thought that was just stored.
    private func classifyInBackground(_ thought: Thought) {
        let repository = repository
        let intelligence = intelligence
        let changes = changes

        classificationTask = Task {
            let result = await intelligence.classify(thought.body)
            guard result != .unknown else { return }

            var classified = thought
            classified.applyClassification(kind: result.kind, title: result.title)
            try? await repository.update(classified)
            changes.notify()
        }
    }

    /// The captured text with surrounding whitespace removed.
    ///
    /// Only the outer whitespace is touched. Everything the user typed inside the thought,
    /// including line breaks, is stored exactly as written.
    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
