import Core
import Foundation

/// A classifier that returns whatever it was told to, for previews and tests.
public struct StubIntelligence: IntelligenceService {
    private let result: Classification
    private let reported: IntelligenceAvailability
    private let delay: Duration?
    private let questions: [String]
    private let generatedWriteUp: WriteUp?
    private let line: String?

    /// Creates a stub.
    /// - Parameters:
    ///   - result: What every call returns. Defaults to ``Classification/unknown``.
    ///   - availability: What to report as the current implementation.
    ///   - delay: An artificial pause before answering, for exercising timeouts.
    ///   - questions: What ``interviewQuestions(for:)`` returns.
    ///   - writeUp: What ``writeUp(for:answers:at:)`` returns.
    ///   - resurfacingLine: What ``resurfacingLine(for:)`` returns.
    public init(
        result: Classification = .unknown,
        availability: IntelligenceAvailability = .onDevice,
        delay: Duration? = nil,
        questions: [String] = [],
        writeUp: WriteUp? = nil,
        resurfacingLine: String? = nil
    ) {
        self.result = result
        reported = availability
        self.delay = delay
        self.questions = questions
        generatedWriteUp = writeUp
        line = resurfacingLine
    }

    public var availability: IntelligenceAvailability {
        reported
    }

    public func classify(_: String) async -> Classification {
        if let delay {
            try? await Task.sleep(for: delay)
        }
        return result
    }

    public func interviewQuestions(for _: String) async -> [String] {
        if let delay {
            try? await Task.sleep(for: delay)
        }
        return questions
    }

    public func writeUp(
        for _: String,
        answers _: [AnsweredQuestion],
        at _: Date
    ) async -> WriteUp? {
        if let delay {
            try? await Task.sleep(for: delay)
        }
        return generatedWriteUp
    }

    public func resurfacingLine(for _: String) async -> String? {
        if let delay {
            try? await Task.sleep(for: delay)
        }
        return line
    }
}
