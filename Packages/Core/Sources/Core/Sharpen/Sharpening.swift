import Foundation

/// An in-progress or finished sharpening of one thought.
///
/// Held on the thought itself and written to storage after every answer, so an interrupted
/// interview loses nothing.
public struct Sharpening: Equatable, Sendable {
    /// The questions asked, in order.
    public private(set) var questions: [SharpenQuestion]

    /// The write-up produced from the answers, or `nil` if it has not been generated yet.
    public private(set) var writeUp: WriteUp?

    /// When the interview began.
    public let startedAt: Date

    /// Creates a sharpening.
    /// - Parameters:
    ///   - questions: The questions to ask.
    ///   - startedAt: When the interview began.
    ///   - writeUp: An already-generated write-up, if any.
    public init(questions: [SharpenQuestion], startedAt: Date, writeUp: WriteUp? = nil) {
        self.questions = questions
        self.startedAt = startedAt
        self.writeUp = writeUp
    }

    /// The next question still needing an answer, or `nil` when every question is answered.
    public var nextUnanswered: SharpenQuestion? {
        questions.first { !$0.isAnswered }
    }

    /// How many questions have been answered.
    public var answeredCount: Int {
        questions.count(where: \.isAnswered)
    }

    /// Whether every question has an answer and a write-up can be produced.
    public var isReadyForWriteUp: Bool {
        !questions.isEmpty && nextUnanswered == nil
    }

    /// The answered questions, in order, for handing to a model.
    public var answers: [AnsweredQuestion] {
        questions.compactMap { question in
            guard let answer = question.answer, question.isAnswered else { return nil }
            return AnsweredQuestion(question: question.prompt, answer: answer)
        }
    }

    /// Records an answer to a question.
    ///
    /// Changing an answer discards any write-up built on the old one, so the result can never
    /// claim to be grounded in something the user has since revised.
    /// - Parameters:
    ///   - text: What the user typed.
    ///   - id: Which question they answered.
    public mutating func answer(_ text: String, to id: SharpenQuestion.ID) {
        guard let index = questions.firstIndex(where: { $0.id == id }) else { return }
        let previous = questions[index].answer
        questions[index].record(text)
        if questions[index].answer != previous {
            writeUp = nil
        }
    }

    /// Attaches a generated write-up.
    /// - Parameter writeUp: The write-up produced from the current answers.
    public mutating func attach(_ writeUp: WriteUp) {
        self.writeUp = writeUp
    }
}
