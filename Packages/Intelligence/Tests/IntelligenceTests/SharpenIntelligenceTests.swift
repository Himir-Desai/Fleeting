import Core
import Foundation
@testable import Intelligence
import Testing

@Suite("Heuristic sharpening")
struct HeuristicSharpeningTests {
    private let subject = HeuristicIntelligence()
    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("the rules ask three answerable questions")
    func asksThreeQuestions() async {
        let questions = await subject.interviewQuestions(for: "app for splitting rent fairly")
        #expect(questions.count == 3)
        #expect(questions.allSatisfy { $0.hasSuffix("?") })
    }

    @Test("an empty note produces no interview")
    func emptyNoteAsksNothing() async {
        #expect(await subject.interviewQuestions(for: "   ").isEmpty)
    }

    @Test("every part of the write-up traces back to something the user said")
    func writeUpUsesOnlyUserAnswers() async throws {
        let answers = [
            AnsweredQuestion(question: HeuristicInterview.audience, answer: "4–6 person student houses"),
            AnsweredQuestion(question: HeuristicInterview.difficulty, answer: "agreeing what fair means"),
            AnsweredQuestion(question: HeuristicInterview.firstStep, answer: "write the split formula")
        ]

        let result = try #require(
            await subject.writeUp(for: "app for splitting rent fairly", answers: answers, at: epoch)
        )

        #expect(result.pitch == "app for splitting rent fairly")
        #expect(result.audience == "4–6 person student houses")
        #expect(result.biggestRisk == "agreeing what fair means")
        #expect(result.firstStep == "write the split formula")
    }

    @Test("no answers means no write-up, rather than an invented one")
    func noAnswersNoWriteUp() async {
        #expect(await subject.writeUp(for: "an idea", answers: [], at: epoch) == nil)
    }

    @Test("the escalation prompt is self-contained")
    func escalationPromptCarriesEverything() async {
        let answers = [AnsweredQuestion(question: "Who?", answer: "student houses")]
        let writeUp = WriteUp(
            pitch: "A fair rent calculator", audience: "student houses",
            firstStep: "write the formula", biggestRisk: "Splitwise", generatedAt: epoch
        )

        let prompt = await subject.escalationPrompt(
            for: "app for splitting rent fairly",
            answers: answers,
            writeUp: writeUp
        )

        #expect(prompt.contains("app for splitting rent fairly"))
        #expect(prompt.contains("student houses"))
        #expect(prompt.contains("A fair rent calculator"))
        #expect(prompt.contains("do not invent"))
    }

    @Test("escalation works before any interview has happened")
    func escalationWorksWithNothingYet() async {
        let prompt = await subject.escalationPrompt(for: "a bare idea", answers: [], writeUp: nil)
        #expect(prompt.contains("a bare idea"))
    }
}

@Suite("Resilient sharpening")
struct ResilientSharpeningTests {
    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    private var rules: HeuristicIntelligence {
        HeuristicIntelligence()
    }

    @Test("a slow model loses the interview to the clock and the rules take over")
    func slowInterviewDegrades() async {
        let subject = ResilientIntelligence(
            primary: StubIntelligence(delay: .seconds(30), questions: ["Never arrives?"]),
            fallback: rules,
            timeout: .milliseconds(40)
        )

        let questions = await subject.interviewQuestions(for: "an idea")

        #expect(questions == HeuristicInterview.questions)
        #expect(await subject.availability == .heuristic(reason: .requestFailed))
    }

    @Test("a model with no questions degrades rather than leaving the screen empty")
    func emptyInterviewDegrades() async {
        let subject = ResilientIntelligence(
            primary: StubIntelligence(questions: []),
            fallback: rules
        )

        #expect(await subject.interviewQuestions(for: "an idea") == HeuristicInterview.questions)
    }

    @Test("a model that cannot write up the answers falls back to assembling them")
    func writeUpDegrades() async {
        let subject = ResilientIntelligence(
            primary: StubIntelligence(questions: ["Who?"], writeUp: nil),
            fallback: rules
        )
        let answers = [
            AnsweredQuestion(question: HeuristicInterview.audience, answer: "student houses")
        ]

        let result = await subject.writeUp(for: "an idea", answers: answers, at: epoch)

        #expect(result?.audience == "student houses")
    }

    @Test("a working model's interview is used as given")
    func workingModelIsUsed() async {
        let subject = ResilientIntelligence(
            primary: StubIntelligence(questions: ["What is the hard part?"]),
            fallback: rules
        )

        #expect(await subject.interviewQuestions(for: "an idea") == ["What is the hard part?"])
    }
}
