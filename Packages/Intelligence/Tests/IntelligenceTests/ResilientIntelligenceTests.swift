import Core
import Foundation
@testable import Intelligence
import Testing

@Suite("ResilientIntelligence")
struct ResilientIntelligenceTests {
    private let onDeviceAnswer = Classification(kind: .idea, title: "From the model", confidence: 0.9)

    private func heuristicOnly() -> StubIntelligence {
        StubIntelligence(
            result: Classification(kind: .todo, title: "From the rules", confidence: 0.7),
            availability: .heuristic(reason: .notBuiltIn)
        )
    }

    @Test("a working model answers, and the app reports itself as on-device")
    func primaryAnswers() async {
        let subject = ResilientIntelligence(
            primary: StubIntelligence(result: onDeviceAnswer),
            fallback: heuristicOnly()
        )

        #expect(await subject.classify("anything") == onDeviceAnswer)
        #expect(await subject.availability == .onDevice)
    }

    @Test("a device with no model at all still classifies")
    func noPrimaryStillWorks() async {
        let subject = ResilientIntelligence(primary: nil, fallback: heuristicOnly())

        #expect(await subject.classify("call the dentist").title == "From the rules")
        #expect(await subject.availability == .heuristic(reason: .notBuiltIn))
    }

    @Test("a model that reports itself unavailable is not called")
    func unavailablePrimaryDegrades() async {
        let subject = ResilientIntelligence(
            primary: StubIntelligence(
                result: onDeviceAnswer,
                availability: .heuristic(reason: .modelDisabled)
            ),
            fallback: heuristicOnly()
        )

        #expect(await subject.classify("anything").title == "From the rules")
        #expect(await subject.availability == .heuristic(reason: .modelDisabled))
    }

    @Test("a slow model loses to the clock rather than delaying the app")
    func timeoutDegrades() async {
        let subject = ResilientIntelligence(
            primary: StubIntelligence(result: onDeviceAnswer, delay: .seconds(30)),
            fallback: heuristicOnly(),
            timeout: .milliseconds(40)
        )

        #expect(await subject.classify("anything").title == "From the rules")
        #expect(await subject.availability == .heuristic(reason: .requestFailed))
    }

    @Test("a model that answers with nothing is treated as a failure")
    func unknownAnswerDegrades() async {
        let subject = ResilientIntelligence(
            primary: StubIntelligence(result: .unknown),
            fallback: heuristicOnly()
        )

        #expect(await subject.classify("anything").title == "From the rules")
    }

    @Test("recovering from a failure is reported honestly")
    func availabilityRecovers() async {
        let subject = ResilientIntelligence(
            primary: StubIntelligence(result: onDeviceAnswer),
            fallback: heuristicOnly(),
            timeout: .seconds(5)
        )

        _ = await subject.classify("anything")
        #expect(await subject.availability == .onDevice)
    }
}
