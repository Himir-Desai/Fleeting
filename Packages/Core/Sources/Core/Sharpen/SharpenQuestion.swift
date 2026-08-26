import Foundation

/// One question in a sharpening interview, and the answer to it if given.
public struct SharpenQuestion: Identifiable, Equatable, Sendable {
    /// Stable identity, so answers survive the list being rebuilt.
    public let id: UUID

    /// What the user is being asked.
    public let prompt: String

    /// What they answered, or `nil` if they have not yet.
    public private(set) var answer: String?

    /// Creates a question.
    /// - Parameters:
    ///   - id: Stable identity. Defaults to a fresh identifier.
    ///   - prompt: The question text.
    ///   - answer: An answer already given, if any.
    public init(id: UUID = UUID(), prompt: String, answer: String? = nil) {
        self.id = id
        self.prompt = prompt
        self.answer = answer
    }

    /// Whether this question has a usable answer.
    public var isAnswered: Bool {
        guard let answer else { return false }
        return !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Records an answer, or clears it if the text is blank.
    /// - Parameter text: What the user typed.
    public mutating func record(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        answer = trimmed.isEmpty ? nil : trimmed
    }
}

/// A question paired with the answer given to it, for handing to a model.
public struct AnsweredQuestion: Equatable, Sendable {
    /// What was asked.
    public let question: String

    /// What the user said.
    public let answer: String

    /// Creates a pair.
    /// - Parameters:
    ///   - question: What was asked.
    ///   - answer: What the user said.
    public init(question: String, answer: String) {
        self.question = question
        self.answer = answer
    }
}
