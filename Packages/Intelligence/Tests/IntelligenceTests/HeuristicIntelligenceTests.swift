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

    @Test(
        "a habit's frequency is read out of its own words",
        arguments: [
            ("run every morning", HabitCadence.daily),
            ("stretch every day before coffee", .daily),
            ("meditate daily", .daily),
            ("call mum every sunday", .weekly),
            ("read a chapter every week", .weekly),
            ("weekly review of the inbox", .weekly),
            ("tidy the flat every other week", .fortnightly),
            ("every two weeks, water the plants", .fortnightly),
            ("pay the cleaner every month", .monthly),
            ("gym every other day", .everyFewDays)
        ]
    )
    func readsCadenceFromWording(text: String, expected: HabitCadence) async {
        let result = await subject.classify(text)

        #expect(result.kind == .habit, "\(text) should sort as a habit")
        #expect(result.cadence == expected)
    }

    @Test("a habit that names no frequency gets none invented for it")
    func silentHabitHasNoCadence() async {
        let result = await subject.classify("make reading a habit")

        #expect(result.kind == .habit)
        #expect(result.cadence == nil, "a guess here would be worse than the default")
    }

    @Test("a cadence is only ever carried by a habit")
    func onlyHabitsCarryACadence() async {
        // The rules cannot tell "buy the daily paper" from a daily routine, and deliberately
        // prefer habit when a frequency is present. What must hold is the invariant one level
        // down: anything not sorted as a habit carries no cadence at all.
        let todo = await subject.classify("pay the parking fine")
        let idea = await subject.classify("an app that ranks coffee shops")

        #expect(todo.kind == .todo)
        #expect(todo.cadence == nil)
        #expect(idea.cadence == nil)
    }

    @Test("a cadence is dropped when the kind is not a habit, whatever the classifier says")
    func classificationRefusesACadenceForOtherKinds() {
        // Guards the domain type rather than the rules: a future classifier that answers
        // "todo, weekly" must not produce a to-do with a rhythm.
        let confused = Classification(kind: .todo, title: nil, confidence: 1, cadence: .weekly)

        #expect(confused.cadence == nil)
    }

    @Test("the more specific frequency wins when two could match")
    func longerPeriodsWinOverShorterOnes() async {
        // "every two weeks" also contains "week"; the fortnightly reading is the right one.
        #expect(await subject.classify("every two weeks, deep clean").cadence == .fortnightly)
        // "every month" would also match nothing else, but proves the ordering holds at the top.
        #expect(await subject.classify("every month, review the budget").cadence == .monthly)
    }
}
