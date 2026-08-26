import Core
import Foundation
import Observation

/// State and rules for sharpening one half-formed idea.
///
/// Every answer is written to storage as it is given, so an interview interrupted by a force-quit
/// resumes exactly where it stopped.
@MainActor
@Observable
public final class SharpenModel {
    /// Where the interview has got to.
    public enum Phase: Equatable {
        /// Nothing has started yet.
        case idle
        /// Asking the model what it needs to know.
        case preparing
        /// Waiting for the user to answer the current question.
        case interviewing
        /// Organising the answers into a write-up.
        case writing
        /// A write-up exists.
        case finished
        /// Something failed, with a sentence explaining what.
        case failed(String)
    }

    /// The thought being sharpened, including any interview already stored on it.
    public private(set) var thought: Thought

    /// Where the interview has got to.
    public private(set) var phase: Phase = .idle

    /// What the user is typing in answer to the current question.
    public var draftAnswer: String = ""

    /// What is answering, so the screen can say plainly when it is running on rules.
    public private(set) var availability: IntelligenceAvailability?

    /// The prompt to hand to a full assistant, once there is enough to hand over.
    public private(set) var escalationPrompt: String?

    private let repository: any ThoughtRepository
    private let intelligence: any IntelligenceService
    private let changes: ThoughtChangeNotifier
    private let clock: any WallClock
    private var work: Task<Void, Never>?

    /// Creates the sharpening screen's state.
    /// - Parameters:
    ///   - thought: The idea to sharpen.
    ///   - repository: Where each answer is written back.
    ///   - intelligence: Asks the questions and organises the answers.
    ///   - changes: Told when the thought changes, so other screens refresh.
    ///   - clock: Time source for answers and the write-up.
    public init(
        thought: Thought,
        repository: any ThoughtRepository,
        intelligence: any IntelligenceService,
        changes: ThoughtChangeNotifier = ThoughtChangeNotifier(),
        clock: any WallClock
    ) {
        self.thought = thought
        self.repository = repository
        self.intelligence = intelligence
        self.changes = changes
        self.clock = clock
    }

    /// The question currently being asked, if any.
    public var currentQuestion: SharpenQuestion? {
        thought.sharpening?.nextUnanswered
    }

    /// The write-up, once one exists.
    public var writeUp: WriteUp? {
        thought.sharpening?.writeUp
    }

    /// How many questions have been answered, and how many there are.
    public var progress: (answered: Int, total: Int) {
        guard let sharpening = thought.sharpening else { return (0, 0) }
        return (sharpening.answeredCount, sharpening.questions.count)
    }

    /// Whether the answer currently typed is worth submitting.
    public var canSubmit: Bool {
        !draftAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Resumes a stored interview, or asks for a new one.
    public func start() async {
        availability = await intelligence.availability

        if let sharpening = thought.sharpening, !sharpening.questions.isEmpty {
            if sharpening.writeUp != nil {
                phase = .finished
                await prepareEscalation()
            } else if sharpening.isReadyForWriteUp {
                // Every question is answered but no write-up exists: either a previous
                // attempt failed, or the review answered the only question that was asked.
                await writeUpAnswers()
            } else {
                phase = .interviewing
            }
            return
        }

        await askForQuestions()
    }

    /// Asks the intelligence layer for an interview.
    public func askForQuestions() async {
        phase = .preparing
        let prompts = await intelligence.interviewQuestions(for: thought.body)

        guard !prompts.isEmpty else {
            phase = .failed("Couldn't think of anything to ask. Your note is untouched.")
            return
        }

        thought.beginSharpening(prompts: prompts, at: clock.now)
        guard await persist() else { return }
        phase = .interviewing
    }

    /// Records the typed answer against the current question and moves on.
    public func submitAnswer() async {
        guard canSubmit, let question = currentQuestion else { return }

        thought.answerSharpening(draftAnswer, to: question.id, at: clock.now)

        // The draft is cleared only once the answer is safely stored, so a storage failure
        // never costs the user something they have already typed.
        guard await persist() else { return }
        draftAnswer = ""

        if thought.sharpening?.isReadyForWriteUp == true {
            await writeUpAnswers()
        }
    }

    /// Organises the answers into a write-up.
    public func writeUpAnswers() async {
        guard let answers = thought.sharpening?.answers, !answers.isEmpty else { return }

        phase = .writing
        let generated = await intelligence.writeUp(
            for: thought.body,
            answers: answers,
            at: clock.now
        )

        guard let generated else {
            phase = .failed("Couldn't write it up. Your answers are saved — try again.")
            return
        }

        thought.attachWriteUp(generated, at: clock.now)
        guard await persist() else { return }
        await prepareEscalation()
        phase = .finished
    }

    /// Whether there is a sharpening to undo.
    public var canRevert: Bool {
        thought.hasBeenSharpened
    }

    /// Returns the thought to how it was before it was ever sharpened.
    ///
    /// Removes the interview and the write-up together. The captured text was never altered, so
    /// what remains is the note exactly as written.
    /// - Returns: `true` when the change was stored, so the caller can leave the screen.
    public func revert() async -> Bool {
        thought.revertSharpening()
        guard await persist() else { return false }
        escalationPrompt = nil
        phase = .idle
        return true
    }

    /// Abandons the current in-flight request without losing anything already answered.
    public func cancel() {
        work?.cancel()
        work = nil
        phase = thought.sharpening?.writeUp == nil ? .interviewing : .finished
    }

    /// Builds the prompt handed to a full assistant when an idea outgrows on-device help.
    private func prepareEscalation() async {
        escalationPrompt = await intelligence.escalationPrompt(
            for: thought.body,
            answers: thought.sharpening?.answers ?? [],
            writeUp: writeUp
        )
    }

    /// Writes the thought back and tells other screens it changed.
    /// - Returns: `true` when the write succeeded. On failure the phase is set to `.failed` and
    ///   callers must stop, rather than continuing as though the answer had been stored.
    private func persist() async -> Bool {
        do {
            try await repository.update(thought)
            changes.notify()
            return true
        } catch {
            phase = .failed("Couldn't save that. Your note is untouched.")
            return false
        }
    }
}
