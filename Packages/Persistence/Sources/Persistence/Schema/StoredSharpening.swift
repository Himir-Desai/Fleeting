import Core
import Foundation

/// The stored spelling of a ``Core/Sharpening``.
///
/// A separate `Codable` type rather than making the domain codable: storage shape and domain shape
/// evolve for different reasons, and this is the one place they meet (ADR-0003).
struct StoredSharpening: Codable {
    struct StoredQuestion: Codable {
        var id: UUID
        var prompt: String
        var answer: String?
    }

    struct StoredWriteUp: Codable {
        var title: String
        var detail: String
        var generatedAt: Date
    }

    var questions: [StoredQuestion]
    var writeUp: StoredWriteUp?
    var startedAt: Date

    /// Creates the stored form of a domain sharpening.
    /// - Parameter sharpening: The sharpening to store.
    init(_ sharpening: Sharpening) {
        questions = sharpening.questions.map {
            StoredQuestion(id: $0.id, prompt: $0.prompt, answer: $0.answer)
        }
        writeUp = sharpening.writeUp.map {
            StoredWriteUp(title: $0.title, detail: $0.detail, generatedAt: $0.generatedAt)
        }
        startedAt = sharpening.startedAt
    }

    /// The domain sharpening this row represents.
    var domain: Sharpening {
        Sharpening(
            questions: questions.map {
                SharpenQuestion(id: $0.id, prompt: $0.prompt, answer: $0.answer)
            },
            startedAt: startedAt,
            writeUp: writeUp.map {
                WriteUp(title: $0.title, detail: $0.detail, generatedAt: $0.generatedAt)
            }
        )
    }

    /// Encodes a sharpening for storage.
    /// - Parameter sharpening: The sharpening to encode, if any.
    /// - Returns: JSON text, or `nil` when there is nothing to store.
    static func encode(_ sharpening: Sharpening?) -> String? {
        guard let sharpening else { return nil }
        guard let data = try? JSONEncoder().encode(StoredSharpening(sharpening)) else { return nil }
        return String(bytes: data, encoding: .utf8)
    }

    /// Decodes a stored sharpening.
    ///
    /// Unreadable text yields `nil` rather than throwing: a corrupt interview must cost the user
    /// their questions, never their thought.
    /// - Parameter json: The stored text.
    /// - Returns: The sharpening, or `nil`.
    static func decode(_ json: String?) -> Sharpening? {
        guard let json, let data = json.data(using: .utf8) else { return nil }
        return (try? JSONDecoder().decode(StoredSharpening.self, from: data))?.domain
    }
}
