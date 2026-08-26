@testable import Core
import Foundation
import Testing

@Suite("Sharpening")
struct SharpeningTests {
    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    private func idea() -> Thought {
        var thought = Thought(body: "app for splitting rent fairly", capturedAt: epoch)
        thought.applyClassification(kind: .idea, title: nil)
        return thought
    }

    @Test("only ideas can be sharpened")
    func onlyIdeas() {
        var todo = Thought(body: "call the dentist", capturedAt: epoch)
        todo.applyClassification(kind: .todo, title: nil)

        #expect(idea().canBeSharpened)
        #expect(!todo.canBeSharpened)
    }

    @Test("questions are asked one at a time, in order")
    func questionsAreOrdered() throws {
        var thought = idea()
        thought.beginSharpening(prompts: ["Who?", "What's hard?", "First step?"], at: epoch)

        #expect(thought.sharpening?.nextUnanswered?.prompt == "Who?")

        let first = try #require(thought.sharpening?.questions.first)
        thought.answerSharpening("students", to: first.id, at: epoch)

        #expect(thought.sharpening?.nextUnanswered?.prompt == "What's hard?")
        #expect(thought.sharpening?.answeredCount == 1)
    }

    @Test("blank answers do not count as answered")
    func blankAnswersDoNotCount() throws {
        var thought = idea()
        thought.beginSharpening(prompts: ["Who?"], at: epoch)
        let question = try #require(thought.sharpening?.questions.first)

        thought.answerSharpening("   \n ", to: question.id, at: epoch)

        #expect(thought.sharpening?.answeredCount == 0)
        #expect(thought.sharpening?.isReadyForWriteUp == false)
    }

    @Test("a write-up becomes possible only once every question is answered")
    func readinessRequiresEveryAnswer() {
        var thought = idea()
        thought.beginSharpening(prompts: ["Who?", "What's hard?"], at: epoch)
        let questions = thought.sharpening?.questions ?? []

        thought.answerSharpening("students", to: questions[0].id, at: epoch)
        #expect(thought.sharpening?.isReadyForWriteUp == false)

        thought.answerSharpening("the maths", to: questions[1].id, at: epoch)
        #expect(thought.sharpening?.isReadyForWriteUp == true)
    }

    @Test("answering counts as deliberate action, so sharpening keeps an idea alive")
    func answeringRestoresFreshness() throws {
        var thought = idea()
        thought.beginSharpening(prompts: ["Who?"], at: epoch)
        let question = try #require(thought.sharpening?.questions.first)
        let later = epoch.addingTimeInterval(60 * .day)

        thought.answerSharpening("students", to: question.id, at: later)

        #expect(DecayEngine().freshness(of: thought, at: later) == .full)
    }

    @Test("changing an answer discards a write-up built on the old one")
    func revisingAnAnswerInvalidatesTheWriteUp() throws {
        var thought = idea()
        thought.beginSharpening(prompts: ["Who?"], at: epoch)
        let question = try #require(thought.sharpening?.questions.first)
        thought.answerSharpening("students", to: question.id, at: epoch)
        thought.attachWriteUp(
            WriteUp(
                pitch: "p", audience: "students", firstStep: "f",
                biggestRisk: "r", generatedAt: epoch
            ),
            at: epoch
        )
        #expect(thought.sharpening?.writeUp != nil)

        thought.answerSharpening("landlords", to: question.id, at: epoch)

        #expect(
            thought.sharpening?.writeUp == nil,
            "a write-up must never claim to be grounded in an answer that has changed"
        )
    }

    @Test("re-answering with the same words keeps the write-up")
    func unchangedAnswerKeepsTheWriteUp() throws {
        var thought = idea()
        thought.beginSharpening(prompts: ["Who?"], at: epoch)
        let question = try #require(thought.sharpening?.questions.first)
        thought.answerSharpening("students", to: question.id, at: epoch)
        thought.attachWriteUp(
            WriteUp(
                pitch: "p", audience: "students", firstStep: "f",
                biggestRisk: "r", generatedAt: epoch
            ),
            at: epoch
        )

        thought.answerSharpening("students", to: question.id, at: epoch)

        #expect(thought.sharpening?.writeUp != nil)
    }

    @Test("sharpening never touches the raw captured text")
    func rawTextIsUntouched() throws {
        var thought = idea()
        thought.beginSharpening(prompts: ["Who?"], at: epoch)
        let question = try #require(thought.sharpening?.questions.first)
        thought.answerSharpening("students", to: question.id, at: epoch)
        thought.attachWriteUp(
            WriteUp(
                pitch: "A fair rent calculator", audience: "students",
                firstStep: "sketch the formula", biggestRisk: "Splitwise", generatedAt: epoch
            ),
            at: epoch
        )

        #expect(thought.body == "app for splitting rent fairly")
    }

    @Test("answers are handed over in the order they were asked")
    func answersPreserveOrder() {
        var thought = idea()
        thought.beginSharpening(prompts: ["Who?", "What's hard?"], at: epoch)
        let questions = thought.sharpening?.questions ?? []
        thought.answerSharpening("students", to: questions[0].id, at: epoch)
        thought.answerSharpening("the maths", to: questions[1].id, at: epoch)

        #expect(thought.sharpening?.answers.map(\.answer) == ["students", "the maths"])
        #expect(thought.sharpening?.answers.first?.question == "Who?")
    }

    @Test("discarding an interview leaves the thought itself intact")
    func discardingKeepsTheThought() {
        var thought = idea()
        thought.beginSharpening(prompts: ["Who?"], at: epoch)

        thought.discardSharpening()

        #expect(thought.sharpening == nil)
        #expect(thought.body == "app for splitting rent fairly")
    }
}
