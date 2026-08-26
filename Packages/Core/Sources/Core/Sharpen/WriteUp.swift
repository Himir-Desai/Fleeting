import Foundation

/// The result of sharpening a half-formed idea: a title, and the idea developed into a paragraph.
///
/// Both are meant to be traceable to something the user said. The model's job is to expand and
/// organise their answers, not to supply the parts they did not give.
public struct WriteUp: Equatable, Sendable {
    /// A short title for the developed idea.
    public let title: String

    /// The idea written out properly, in a paragraph.
    public let detail: String

    /// When it was produced.
    public let generatedAt: Date

    /// Creates a write-up.
    /// - Parameters:
    ///   - title: A short title for the developed idea.
    ///   - detail: The idea developed into a paragraph.
    ///   - generatedAt: When it was produced.
    public init(title: String, detail: String, generatedAt: Date) {
        self.title = title
        self.detail = detail
        self.generatedAt = generatedAt
    }
}
