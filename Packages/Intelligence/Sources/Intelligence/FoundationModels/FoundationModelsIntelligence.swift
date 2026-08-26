#if canImport(FoundationModels)
    import Core
    import Foundation
    import FoundationModels

    /// Classifies captured text with Apple's on-device language model.
    ///
    /// Uses guided generation so the model returns a typed value rather than prose that has to be
    /// parsed. Never surfaces an error: an unusable model returns ``Classification/unknown`` and
    /// ``ResilientIntelligence`` degrades to heuristics.
    @available(iOS 26, macOS 26, *)
    public struct FoundationModelsIntelligence: IntelligenceService {
        /// Creates the on-device classifier.
        public init() {}

        public var availability: IntelligenceAvailability {
            switch SystemLanguageModel.default.availability {
            case .available:
                .onDevice
            case let .unavailable(reason):
                .heuristic(reason: Self.map(reason))
            @unknown default:
                .heuristic(reason: .modelUnsupported)
            }
        }

        public func classify(_ text: String) async -> Classification {
            guard case .onDevice = availability else { return .unknown }

            let session = LanguageModelSession(instructions: Self.instructions)
            do {
                let response = try await session.respond(
                    to: Self.prompt(for: text),
                    generating: GeneratedClassification.self
                )
                return response.content.asDomain
            } catch {
                return .unknown
            }
        }

        /// Translates the framework's unavailability reason into the app's vocabulary.
        /// - Parameter reason: Why the system reports the model as unusable.
        /// - Returns: The matching app-level reason.
        private static func map(
            _ reason: SystemLanguageModel.Availability.UnavailableReason
        ) -> HeuristicReason {
            switch reason {
            case .deviceNotEligible: .modelUnsupported
            case .appleIntelligenceNotEnabled: .modelDisabled
            case .modelNotReady: .modelNotReady
            @unknown default: .modelUnsupported
            }
        }

        /// Standing instructions for the classification session.
        private static var instructions: String {
            """
            You sort short personal notes captured in a hurry. Decide whether each note is an \
            idea worth developing, a todo to be done once, a habit the writer wants to repeat, \
            or unsorted when it is genuinely none of those. Write a short title of at most six \
            words using the writer's own words. Never invent details the note does not contain.
            """
        }

        /// Builds the per-note prompt.
        /// - Parameter text: The raw captured text.
        /// - Returns: The prompt to send.
        private static func prompt(for text: String) -> String {
            "Sort this note:\n\(text)"
        }
    }

    /// The structured value the model is asked to produce.
    @available(iOS 26, macOS 26, *)
    @Generable
    struct GeneratedClassification {
        @Guide(description: "Exactly one of: idea, todo, habit, unsorted")
        var kind: String

        @Guide(description: "A title of at most six words, drawn from the note's own wording")
        var title: String

        @Guide(description: "How certain the sorting is, from 0 to 1")
        var confidence: Double
    }

    @available(iOS 26, macOS 26, *)
    extension GeneratedClassification {
        /// The domain classification this generation represents.
        ///
        /// An unrecognised kind degrades to unsorted rather than failing: a model that answers
        /// oddly must not cost the user their thought.
        var asDomain: Classification {
            let resolved = ThoughtKind(rawValue: kind.lowercased()) ?? .unsorted
            let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
            return Classification(
                kind: resolved,
                title: cleaned.isEmpty ? nil : cleaned,
                confidence: confidence
            )
        }
    }
#endif
