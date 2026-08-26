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

        let thought = Thought(body: trimmedText, capturedAt: clock.now)
        isSaving = true
        defer { isSaving = false }

        do {
            try await repository.add(thought)
            text = ""
            lastError = nil
            savedCount += 1
            changes.notify()
            classifyInBackground(thought)
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
