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

        /// Asks the model what it would need to know to sharpen this idea.
        public func interviewQuestions(for text: String) async -> [String] {
            guard case .onDevice = availability else { return [] }

            let session = LanguageModelSession(instructions: Self.interviewInstructions)
            do {
                let response = try await session.respond(
                    to: "Here is the note:\n\(text)",
                    generating: GeneratedQuestions.self
                )
                return response.content.questions
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .prefix(3)
                    .map(\.self)
            } catch {
                return []
            }
        }

        /// Asks the model to organise the user's answers, without adding to them.
        public func writeUp(
            for text: String,
            answers: [AnsweredQuestion],
            at date: Date
        ) async -> WriteUp? {
            guard case .onDevice = availability, !answers.isEmpty else { return nil }

            let session = LanguageModelSession(instructions: Self.writeUpInstructions)
            do {
                let response = try await session.respond(
                    to: Self.writeUpPrompt(text: text, answers: answers),
                    generating: GeneratedWriteUp.self
                )
                return response.content.asDomain(generatedAt: date)
            } catch {
                return nil
            }
        }

        /// Standing instructions for the interview session.
        private static var interviewInstructions: String {
            """
            You help someone sharpen a half-formed idea they jotted down in a hurry. Ask two or \
            three short, specific questions whose answers would make the idea concrete. Ask about \
            what is missing, never about what the note already says. Each question must be one \
            sentence and answerable in a line.
            """
        }

        /// Standing instructions for the write-up session.
        private static var writeUpInstructions: String {
            """
            You develop someone's half-formed idea into one properly written paragraph, and give \
            it a short title. Use only their note and their answers, expanding and connecting what \
            they said rather than adding to it. Never invent a market, a number, a name, or a \
            feature they did not mention. Where something is unresolved, say so plainly.
            """
        }

        /// Builds the write-up prompt from the note and the answers.
        /// - Parameters:
        ///   - text: The raw captured text.
        ///   - answers: What the user said.
        /// - Returns: The prompt to send.
        private static func writeUpPrompt(text: String, answers: [AnsweredQuestion]) -> String {
            let transcript = answers
                .map { "Q: \($0.question)\nA: \($0.answer)" }
                .joined(separator: "\n")
            return "The note:\n\(text)\n\nWhat they told me:\n\(transcript)"
        }

        /// Asks the model for one line that might restart a forgotten thought.
        public func resurfacingLine(for text: String) async -> String? {
            guard case .onDevice = availability else { return nil }

            let session = LanguageModelSession(instructions: Self.nudgeInstructions)
            do {
                let response = try await session.respond(to: "The note:\n\(text)")
                let line = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                return line.isEmpty ? nil : String(line.prefix(160))
            } catch {
                return nil
            }
        }

        /// Standing instructions for notification copy.
        private static var nudgeInstructions: String {
            """
            You write a single short sentence that brings a forgotten note back to someone's mind. \
            Use their own words. Never scold, never imply they are behind, never invent detail the \
            note does not contain. One sentence, no preamble, under twenty words.
            """
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

            When the note is a habit, also say how often it is meant to be done as a number and \
            a unit, reading only what the words actually say: "run every morning" is 1 days, \
            "call mum on sundays" is 1 weeks, "water the plants every three days" is 3 days. \
            When the note names no frequency, answer 0 rather than guessing.
            """
        }

        /// Builds the per-note prompt.
        /// - Parameter text: The raw captured text.
        /// - Returns: The prompt to send.
        private static func prompt(for text: String) -> String {
            "Sort this note:\n\(text)"
        }
    }

    /// The interview the model is asked to produce.
    @available(iOS 26, macOS 26, *)
    @Generable
    struct GeneratedQuestions {
        @Guide(description: "Two or three short questions, each answerable in one line")
        var questions: [String]
    }

    /// The structured summary the model is asked to produce.
    @available(iOS 26, macOS 26, *)
    @Generable
    struct GeneratedWriteUp {
        @Guide(description: "A short title of at most six words, in the writer's own terms")
        var title: String

        @Guide(
            description: """
            One detailed paragraph developing the idea, built only from the note and the writer's \
            answers. Do not add facts they did not give.
            """
        )
        var detail: String
    }

    @available(iOS 26, macOS 26, *)
    extension GeneratedWriteUp {
        /// The domain write-up this generation represents.
        /// - Parameter generatedAt: When it was produced.
        /// - Returns: The write-up.
        func asDomain(generatedAt: Date) -> WriteUp {
            WriteUp(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                detail: detail.trimmingCharacters(in: .whitespacesAndNewlines),
                generatedAt: generatedAt
            )
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

        @Guide(
            description: """
            For a habit, how many units between one doing and the next: 1 for every day or \
            every week, 3 for every three days. Use 0 when the note names no frequency, or \
            when this is not a habit.
            """
        )
        var cadenceCount: Int

        @Guide(
            description: """
            The unit that goes with cadenceCount: exactly one of days, weeks, or months. Use \
            days when the note names no frequency, or when this is not a habit.
            """
        )
        var cadenceUnit: String
    }

    @available(iOS 26, macOS 26, *)
    extension GeneratedClassification {
        /// The cadence the model named, or `nil` when it named none or answered oddly.
        ///
        /// A count of zero is the model's way of saying the note named no frequency, which must
        /// stay `nil` so the default applies rather than a rhythm being invented. An unreadable
        /// unit is also `nil`: a model that answers oddly costs the habit nothing.
        var resolvedCadence: HabitCadence? {
            guard cadenceCount >= 1 else { return nil }
            let normalised = cadenceUnit
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            guard let unit = ExpirationUnit(rawValue: normalised) else { return nil }
            return HabitCadence(count: cadenceCount, unit: unit)
        }

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
                confidence: confidence,
                cadence: resolvedCadence
            )
        }
    }
#endif
