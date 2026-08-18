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

    private let repository: any ThoughtRepository
    private let clock: any WallClock

    /// Creates the capture screen's state.
    /// - Parameters:
    ///   - repository: Where committed thoughts are stored.
    ///   - clock: Time source used to stamp the capture.
    public init(repository: any ThoughtRepository, clock: any WallClock) {
        self.repository = repository
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
        } catch {
            lastError = error
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
