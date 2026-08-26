import Core
import Foundation
@testable import Intelligence
import Testing

@Suite("HeuristicIntelligence")
struct HeuristicIntelligenceTests {
    private let subject = HeuristicIntelligence()

    @Test(
        "errands are recognised as todos",
        arguments: [
            "call the dentist back",
            "buy milk on the way home",
            "need to renew the passport",
            "remember to reply to Sam"
        ]
    )
    func todos(text: String) async {
        #expect(await subject.classify(text).kind == .todo)
    }

    @Test(
        "repetition is recognised as a habit",
        arguments: [
            "read twenty pages every day",
            "stretch each morning before coffee",
            "weekly review of the finances",
            "build a journalling habit"
        ]
    )
    func habits(text: String) async {
        #expect(await subject.classify(text).kind == .habit)
    }

    @Test(
        "speculation is recognised as an idea",
        arguments: [
            "app that ranks coffee shops by outlet count",
            "what if rent were split by income",
            "someone should build a better calendar"
        ]
    )
    func ideas(text: String) async {
        #expect(await subject.classify(text).kind == .idea)
    }

    @Test("a habit that also looks like an errand is still a habit")
    func habitBeatsTodo() async {
        let result = await subject.classify("call mum every sunday")
        #expect(result.kind == .habit)
    }

    @Test("text with no signal stays unsorted rather than being guessed at")
    func unsortedFallback() async {
        let result = await subject.classify("the light in the kitchen at four o'clock")
        #expect(result.kind == .unsorted)
        #expect(result.confidence < 0.5)
    }

    @Test("empty text classifies as nothing at all")
    func emptyIsUnknown() async {
        #expect(await subject.classify("   \n ") == .unknown)
    }

    @Test("a confident classification is more confident than a fallback")
    func confidenceReflectsCertainty() async {
        let matched = await subject.classify("call the dentist back")
        let unmatched = await subject.classify("kitchen light")
        #expect(matched.confidence > unmatched.confidence)
    }

    @Test("no title is generated when it would merely repeat the text")
    func shortTextGetsNoTitle() {
        #expect(HeuristicIntelligence.title(from: "call the dentist") == nil)
    }

    @Test("long text gets a short title drawn from its own words")
    func longTextGetsATitle() {
        let title = HeuristicIntelligence.title(
            from: "app that ranks coffee shops by how many power outlets they have"
        )
        #expect(title == "App that ranks coffee shops by")
    }

    @Test("a title comes from the first line when the capture has several")
    func multilineTitleUsesFirstLine() {
        let title = HeuristicIntelligence.title(from: "rent splitting\nby income, not by room")
        #expect(title == "Rent splitting")
    }

    @Test("heuristics report themselves honestly, never as a model")
    func availabilityIsHonest() async {
        #expect(await subject.availability == .heuristic(reason: .notBuiltIn))
    }
}
