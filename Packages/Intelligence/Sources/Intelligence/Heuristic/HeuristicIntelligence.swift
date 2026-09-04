import Core
import Foundation

/// Classifies captured text with deterministic rules and no model.
///
/// Ships on every device and is the reason the app is complete without Apple Intelligence. It is
/// also the reference behaviour: anything the on-device model does must be at least this good.
public struct HeuristicIntelligence: IntelligenceService {
    private let reason: HeuristicReason

    /// Creates the heuristic classifier.
    /// - Parameter reason: Why heuristics are in use, surfaced in Settings.
    public init(reason: HeuristicReason = .notBuiltIn) {
        self.reason = reason
    }

    public var availability: IntelligenceAvailability {
        .heuristic(reason: reason)
    }

    /// Decides what a captured thought is by looking for phrases characteristic of each kind.
    ///
    /// Order matters: habit markers are checked before todo markers, so "call mum every Sunday"
    /// is a habit rather than an errand.
    public func classify(_ text: String) async -> Classification {
        let normalised = text.lowercased()
        guard !normalised.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .unknown
        }

        let title = Self.title(from: text)

        for (kind, markers) in Self.orderedMarkers where Self.contains(normalised, any: markers) {
            return Classification(
                kind: kind,
                title: title,
                confidence: 0.7,
                cadence: kind == .habit ? Self.cadence(in: normalised) : nil
            )
        }

        return Classification(kind: .unsorted, title: title, confidence: 0.2)
    }

    /// Reads how often a habit is meant to be kept out of its own wording.
    ///
    /// Longest periods first, because "every two weeks" also contains "week" and the more
    /// specific reading is the right one. A note that says nothing about frequency yields `nil`
    /// rather than a guess, so the default applies (ADR-0048).
    /// - Parameter normalised: Lowercased captured text.
    /// - Returns: The cadence the words name, or `nil` if they name none.
    static func cadence(in normalised: String) -> HabitCadence? {
        orderedCadenceMarkers
            .first { contains(normalised, any: $0.1) }
            .map(\.0)
    }

    /// Every frequency phrase, in one flat list, so the habit markers cannot drift from them.
    private static let cadenceMarkers: [String] = orderedCadenceMarkers.flatMap(\.1)

    /// Frequency phrases per cadence, longest period first so the specific reading wins.
    private static let orderedCadenceMarkers: [(HabitCadence, [String])] = [
        (.monthly, ["every month", "each month", "monthly", "once a month"]),
        (.fortnightly, [
            "every fortnight", "fortnightly", "every two weeks", "every other week",
            "biweekly", "once a fortnight"
        ]),
        (.weekly, [
            "every week", "each week", "weekly", "once a week", "every sunday",
            "every monday", "every tuesday", "every wednesday", "every thursday",
            "every friday", "every saturday", "on sundays", "on mondays"
        ]),
        (.everyFewDays, [
            "every few days", "every other day", "every second day", "every couple of days",
            "three times a week", "twice a week"
        ]),
        (.daily, [
            "every day", "everyday", "each day", "every morning", "each morning",
            "every night", "each night", "every evening", "daily", "twice a day"
        ])
    ]

    /// Asks a fixed interview.
    ///
    /// The rules cannot read the idea, so they ask the three questions that are worth answering
    /// about almost any idea rather than pretending to be specific.
    public func interviewQuestions(for text: String) async -> [String] {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        return HeuristicInterview.questions
    }

    /// Assembles the user's own answers into a titled paragraph.
    ///
    /// Invents nothing: every sentence is either the note or something the user typed, joined by
    /// framing taken from the question that was asked. This is the floor the on-device model has
    /// to beat.
    public func writeUp(
        for text: String,
        answers: [AnsweredQuestion],
        at date: Date
    ) async -> WriteUp? {
        guard !answers.isEmpty else { return nil }
        let note = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !note.isEmpty else { return nil }

        let sentences = [Self.sentence(note)] + answers.map(Self.frame)

        return WriteUp(
            title: Self.expansionTitle(from: note),
            detail: sentences.joined(separator: " "),
            generatedAt: date
        )
    }

    /// Quotes the note back without comment.
    ///
    /// The rules cannot say anything insightful about a thought, so they say nothing: showing the
    /// note itself is honest, and a fabricated observation would be worse than none.
    public func resurfacingLine(for text: String) async -> String? {
        let note = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !note.isEmpty else { return nil }
        return note.count <= 120 ? note : String(note.prefix(117)) + "…"
    }

    /// Turns one answer into a sentence, using the question to supply the framing.
    ///
    /// The first-step framing uses a colon rather than "is", because an answer may be a verb
    /// phrase or a noun phrase and only the colon reads correctly for both.
    /// - Parameter answer: The question and what the user said.
    /// - Returns: A sentence built only from the user's words.
    private static func frame(_ answer: AnsweredQuestion) -> String {
        let said = answer.answer.trimmingCharacters(in: .whitespacesAndNewlines)
        switch answer.question {
        case HeuristicInterview.audience: return sentence("It is for \(lowered(said))")
        case HeuristicInterview.difficulty: return sentence("The hard part is \(lowered(said))")
        case HeuristicInterview.firstStep: return sentence("The first thing to try: \(lowered(said))")
        default: return sentence(said)
        }
    }

    /// Lowercases a leading capital so an answer reads naturally mid-sentence.
    /// - Parameter text: The user's answer.
    /// - Returns: The text with its first letter lowercased.
    private static func lowered(_ text: String) -> String {
        guard let first = text.first, first.isUppercase else { return text }
        return first.lowercased() + text.dropFirst()
    }

    /// Ensures a fragment reads as a sentence, without altering its words.
    /// - Parameter text: The fragment.
    /// - Returns: The fragment capitalised and closed with a full stop.
    private static func sentence(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.first else { return trimmed }
        let capitalised = first.uppercased() + trimmed.dropFirst()
        return ".!?".contains(capitalised.last ?? " ") ? capitalised : capitalised + "."
    }

    /// A short title for a developed idea, drawn from the note's own opening words.
    /// - Parameter note: The raw captured text.
    /// - Returns: A title of at most six words.
    static func expansionTitle(from note: String) -> String {
        let words = note
            .split(separator: "\n").first.map(String.init)?
            .split(separator: " ") ?? []
        let clipped = words.prefix(6).joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: " ,.;:-–—?!"))
        guard let first = clipped.first else { return "Untitled" }
        return first.uppercased() + clipped.dropFirst()
    }

    /// Phrase lists per kind, in the order they are tested.
    private static let orderedMarkers: [(ThoughtKind, [String])] = [
        // Every phrase that names a frequency is also a phrase that makes something a habit, so
        // the two lists are one list. Keeping them separate let them drift: "every other day"
        // named a cadence but did not sort as a habit, so the cadence was never read (ADR-0048).
        (.habit, cadenceMarkers + [
            "habit", "routine", "practice ", "stop drinking", "start running"
        ]),
        (.todo, [
            "call ", "email ", "text ", "buy ", "book ", "pay ", "send ", "fix ",
            "renew ", "cancel ", "schedule ", "pick up", "drop off", "reply to",
            "remind me", "remember to", "todo", "to do", "need to", "have to",
            "deadline", "due ", "by tomorrow", "by friday", "before monday"
        ]),
        (.idea, [
            "idea", "what if", "app that", "app for", "build a", "startup",
            "business", "could we", "concept", "product that", "service that",
            "wouldn't it be", "someone should"
        ])
    ]

    /// Whether any marker appears in the normalised text.
    /// - Parameters:
    ///   - text: Lowercased captured text.
    ///   - markers: Phrases to look for.
    /// - Returns: `true` if any marker is present.
    private static func contains(_ text: String, any markers: [String]) -> Bool {
        markers.contains { text.contains($0) }
    }

    /// Builds a short title from captured text.
    ///
    /// Returns `nil` when a title would merely repeat the text, so the list never shows the same
    /// words twice. The raw text is never altered.
    /// - Parameter text: The captured text.
    /// - Returns: A short title, or `nil` if one would add nothing.
    static func title(from text: String) -> String? {
        let firstLine = text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespaces) ?? ""
        guard !firstLine.isEmpty else { return nil }

        let words = firstLine.split(separator: " ")
        let isWholeText = firstLine.count == text.trimmingCharacters(in: .whitespacesAndNewlines).count

        guard words.count > 6 || !isWholeText else { return nil }

        let clipped = words.prefix(6).joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: " ,.;:-–—"))
        guard !clipped.isEmpty else { return nil }

        return clipped.prefix(1).uppercased() + clipped.dropFirst()
    }
}
