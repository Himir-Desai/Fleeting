import Core
import Foundation

/// The fixed interview the rules-based implementation runs.
///
/// Three questions in a deliberate order, because the write-up maps answers back by position: who
/// it is for, what is hard about it, and what could be done this week.
enum HeuristicInterview {
    /// The question asked to establish who the idea is for.
    static let audience = "Who has this problem badly enough to do something about it?"

    /// The question asked to surface the real difficulty.
    static let difficulty = "What is the hardest part of making this real?"

    /// The question asked to find a concrete next action.
    static let firstStep = "What is the smallest thing you could do this week to test it?"

    /// The interview, in the order the write-up expects.
    static let questions = [audience, difficulty, firstStep]

    /// The answer given to a particular question, if it was asked and answered.
    /// - Parameters:
    ///   - question: The question to look for.
    ///   - answers: Everything the user said.
    /// - Returns: The matching answer, or `nil`.
    static func answer(to question: String, in answers: [AnsweredQuestion]) -> String? {
        answers.first { $0.question == question }?.answer
    }
}
