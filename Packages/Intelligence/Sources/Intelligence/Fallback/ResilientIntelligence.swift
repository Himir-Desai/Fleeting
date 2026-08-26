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
