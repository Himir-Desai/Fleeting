import Core
import Foundation

/// A classifier that returns whatever it was told to, for previews and tests.
public struct StubIntelligence: IntelligenceService {
    private let result: Classification
    private let reported: IntelligenceAvailability
    private let delay: Duration?

    /// Creates a stub.
    /// - Parameters:
    ///   - result: What every call returns. Defaults to ``Classification/unknown``.
    ///   - availability: What to report as the current implementation.
    ///   - delay: An artificial pause before answering, for exercising timeouts.
    public init(
        result: Classification = .unknown,
        availability: IntelligenceAvailability = .onDevice,
        delay: Duration? = nil
    ) {
        self.result = result
        reported = availability
        self.delay = delay
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
}
