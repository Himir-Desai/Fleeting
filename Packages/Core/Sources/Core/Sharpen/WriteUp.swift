import Foundation

/// The structured result of sharpening a half-formed idea.
///
/// Every field is meant to be traceable to something the user said. The model's job is to
/// organise their answers, not to supply the parts they did not give.
public struct WriteUp: Equatable, Sendable {
    /// What the idea is, in one or two sentences.
    public let pitch: String

    /// Who it is for.
    public let audience: String

    /// The first concrete thing to do about it.
    public let firstStep: String

    /// The most likely reason it fails.
    public let biggestRisk: String

    /// When it was produced.
    public let generatedAt: Date

    /// Creates a write-up.
    /// - Parameters:
    ///   - pitch: What the idea is.
    ///   - audience: Who it is for.
    ///   - firstStep: The first concrete action.
    ///   - biggestRisk: The most likely failure.
    ///   - generatedAt: When it was produced.
    public init(
        pitch: String,
        audience: String,
        firstStep: String,
        biggestRisk: String,
        generatedAt: Date
    ) {
        self.pitch = pitch
        self.audience = audience
        self.firstStep = firstStep
        self.biggestRisk = biggestRisk
        self.generatedAt = generatedAt
    }
}
