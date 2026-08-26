import Core
import Foundation

/// Tries the on-device model and degrades to heuristics whenever it cannot answer in time.
///
/// Features never test for device capability themselves: the degradation lives here, so every
/// caller gets an answer and the app is never blocked on a model (ADR-0004).
public actor ResilientIntelligence: IntelligenceService {
    private let primary: (any IntelligenceService)?
    private let fallback: any IntelligenceService
    private let timeout: Duration
    private var lastFailure: HeuristicReason?

    /// Creates a resilient classifier.
    /// - Parameters:
    ///   - primary: The preferred implementation, or `nil` when none exists on this device.
    ///   - fallback: The implementation used whenever the primary cannot answer.
    ///   - timeout: How long the primary gets before the fallback takes over.
    public init(
        primary: (any IntelligenceService)?,
        fallback: any IntelligenceService,
        timeout: Duration = .seconds(6)
    ) {
        self.primary = primary
        self.fallback = fallback
        self.timeout = timeout
    }

    /// What is answering right now, including why if the app has degraded.
    public var availability: IntelligenceAvailability {
        get async {
            if let lastFailure {
                return .heuristic(reason: lastFailure)
            }
            guard let primary else { return await fallback.availability }
            return await primary.availability
        }
    }

    /// Classifies with the primary implementation, falling back on timeout, failure, or refusal.
    public func classify(_ text: String) async -> Classification {
        guard let primary else { return await fallback.classify(text) }

        if case let .heuristic(reason) = await primary.availability {
            lastFailure = reason
            return await fallback.classify(text)
        }

        guard let answer = await race(primary, on: text) else {
            lastFailure = .requestFailed
            return await fallback.classify(text)
        }

        guard answer != .unknown else {
            lastFailure = .requestFailed
            return await fallback.classify(text)
        }

        lastFailure = nil
        return answer
    }

    /// Asks the primary for an interview, falling back when it cannot supply one.
    public func interviewQuestions(for text: String) async -> [String] {
        guard let primary, await isPrimaryUsable() else {
            return await fallback.interviewQuestions(for: text)
        }

        let questions = await race { await primary.interviewQuestions(for: text) }
        guard let questions, !questions.isEmpty else {
            lastFailure = .requestFailed
            return await fallback.interviewQuestions(for: text)
        }

        lastFailure = nil
        return questions
    }

    /// Asks the primary to organise the answers, falling back when it cannot.
    public func writeUp(
        for text: String,
        answers: [AnsweredQuestion],
        at date: Date
    ) async -> WriteUp? {
        guard let primary, await isPrimaryUsable() else {
            return await fallback.writeUp(for: text, answers: answers, at: date)
        }

        let generated = await race { await primary.writeUp(for: text, answers: answers, at: date) }
        guard let generated, let unwrapped = generated else {
            lastFailure = .requestFailed
            return await fallback.writeUp(for: text, answers: answers, at: date)
        }

        lastFailure = nil
        return unwrapped
    }

    /// Whether the primary reports itself as able to answer.
    /// - Returns: `true` when the primary is on-device and ready.
    private func isPrimaryUsable() async -> Bool {
        guard let primary else { return false }
        if case let .heuristic(reason) = await primary.availability {
            lastFailure = reason
            return false
        }
        return true
    }

    /// Runs any operation against the clock.
    /// - Parameter operation: The work to race.
    /// - Returns: The result, or `nil` if the timeout won.
    private func race<T: Sendable>(_ operation: @escaping @Sendable () async -> T) async -> T? {
        let limit = timeout
        return await withTaskGroup(of: T?.self) { group in
            group.addTask { await operation() }
            group.addTask {
                try? await Task.sleep(for: limit)
                return nil
            }
            let first = await group.next()
            group.cancelAll()
            return first.flatMap(\.self)
        }
    }

    /// Runs a classification against the clock.
    /// - Parameters:
    ///   - service: The implementation to try.
    ///   - text: The text to classify.
    /// - Returns: The classification, or `nil` if the timeout won.
    private func race(_ service: any IntelligenceService, on text: String) async -> Classification? {
        let limit = timeout
        return await withTaskGroup(of: Classification?.self) { group in
            group.addTask { await service.classify(text) }
            group.addTask {
                try? await Task.sleep(for: limit)
                return nil
            }
            let first = await group.next()
            group.cancelAll()
            return first.flatMap(\.self)
        }
    }
}
