import Foundation

public extension Thought {
    /// Whether this thought is eligible to be sharpened.
    ///
    /// Only ideas: sharpening an errand would be ceremony, and the app's whole argument is against
    /// ceremony.
    var canBeSharpened: Bool {
        kind == .idea
    }

    /// Begins an interview, replacing any previous unfinished one.
    /// - Parameters:
    ///   - prompts: The questions to ask.
    ///   - date: When the interview began.
    mutating func beginSharpening(prompts: [String], at date: Date) {
        sharpening = Sharpening(
            questions: prompts.map { SharpenQuestion(prompt: $0) },
            startedAt: date
        )
    }

    /// Records an answer, which counts as deliberate action.
    /// - Parameters:
    ///   - text: What the user typed.
    ///   - id: Which question they answered.
    ///   - date: When they answered.
    mutating func answerSharpening(_ text: String, to id: SharpenQuestion.ID, at date: Date) {
        guard var current = sharpening else { return }
        current.answer(text, to: id)
        sharpening = current
        markActed(at: date)
    }

    /// Attaches a generated write-up, which counts as deliberate action.
    /// - Parameters:
    ///   - writeUp: The write-up produced from the answers.
    ///   - date: When it was produced.
    mutating func attachWriteUp(_ writeUp: WriteUp, at date: Date) {
        guard var current = sharpening else { return }
        current.attach(writeUp)
        sharpening = current
        markActed(at: date)
    }

    /// Whether there is a sharpening to revert.
    var hasBeenSharpened: Bool {
        sharpening != nil
    }

    /// Reverts the thought to how it was before it was ever sharpened.
    ///
    /// Removes the interview and the write-up together. The raw captured text was never altered,
    /// so what remains is exactly the note as it was written.
    mutating func revertSharpening() {
        sharpening = nil
    }
}
