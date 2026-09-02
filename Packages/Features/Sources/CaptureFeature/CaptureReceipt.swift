import Core
import Foundation

/// What a save just filed, shown for a moment where the text used to be.
///
/// Carries the thought's own words as well as its kind and lifetime, so the receipt can be the
/// text collapsing into a card rather than a banner appearing beside it (ADR-0038).
public struct CaptureReceipt: Equatable, Identifiable, Sendable {
    /// The stored thought's identifier, so a second save replaces the first receipt.
    public let id: Thought.ID

    /// The words that were captured.
    public let body: String

    /// The kind it was filed as, or `nil` when the app has yet to sort it.
    public let kind: ThoughtKind?

    /// How long it will last, in words: "90 days", "2 weeks".
    public let lifetime: String

    /// Creates a receipt.
    /// - Parameters:
    ///   - id: The stored thought's identifier.
    ///   - body: The words that were captured.
    ///   - kind: The kind it was filed as, or `nil` for an unsorted capture.
    ///   - lifetime: How long it will last, in words.
    public init(id: Thought.ID, body: String, kind: ThoughtKind?, lifetime: String) {
        self.id = id
        self.body = body
        self.kind = kind
        self.lifetime = lifetime
    }

    /// The line beneath the words: what it was filed as, and how long it has.
    ///
    /// An unsorted capture says "sorting…" rather than naming a kind, because the app has not
    /// decided yet and claiming otherwise would be a lie the next screen contradicts.
    public var summary: String {
        guard let kind, kind != .unsorted else { return "sorting… · \(lifetime)" }
        return "\(KindGlyph.label(for: kind).lowercased()) · \(lifetime)"
    }
}
