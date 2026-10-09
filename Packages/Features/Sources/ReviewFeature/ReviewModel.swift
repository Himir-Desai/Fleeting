import Core
import Foundation
import Observation

/// State and rules for one review session.
///
/// The session is built once and never grows while it runs, so it always has a visible end.
@MainActor
@Observable
public final class ReviewModel {
    /// What was decided about a thought.
    public enum Outcome: String, Sendable {
        /// Kept, and its freshness restored.
        case acted
        /// Set aside for another week.
        case snoozed
        /// Archived without deletion.
        case archived
    }

    /// A running count of what this session decided.
    public struct Tally: Equatable, Sendable {
        /// How many were acted on.
        public var acted = 0
        /// How many were set aside.
        public var snoozed = 0
        /// How many were let go.
        public var archived = 0

        /// How many decisions were made in total.
        public var total: Int {
            acted + snoozed + archived
        }
    }

    /// A failed decision stays on its current card for retry.
    public private(set) var lastError: String?
    public private(set) var isDeciding = false

    /// The cards dealt for this session, most urgent first.
    public private(set) var cards: [Thought] = []

    /// How far through the session we are.
    public private(set) var position = 0

    /// What has been decided so far.
    public private(set) var tally = Tally()

    /// Whether the session has been built.
    public private(set) var hasLoaded = false

    /// A single question attached to the current idea card, if one has been produced.
    public private(set) var ambientQuestion: String?

    /// What the user is typing in answer to the ambient question.
    public var ambientAnswer = ""

    private let repository: any ThoughtRepository
    private let selector: ReviewSelector
    private let engine: DecayEngine
    private let intelligence: any IntelligenceService
    private let changes: ThoughtChangeNotifier
    private let clock: any WallClock
    public let snoozeDays: Double

    /// Creates a review session.
    /// - Parameters:
    ///   - repository: Where thoughts are read from and decisions written back.
    ///   - selector: Chooses which thoughts need a decision.
    ///   - engine: Used to say when the current card would otherwise archive.
    ///   - intelligence: Supplies the ambient question on idea cards.
    ///   - changes: Told when a decision is made, so other screens refresh.
    ///   - clock: Time source for every decision.
    ///   - snoozeDays: How long Snooze sets a thought aside for.
    public init(
        repository: any ThoughtRepository,
        selector: ReviewSelector = ReviewSelector(),
        engine: DecayEngine = DecayEngine(),
        intelligence: any IntelligenceService,
        changes: ThoughtChangeNotifier = ThoughtChangeNotifier(),
        clock: any WallClock,
        snoozeDays: Double = 7
    ) {
        self.repository = repository
        self.selector = selector
        self.engine = engine
        self.intelligence = intelligence
        self.changes = changes
        self.clock = clock
        self.snoozeDays = snoozeDays
    }

    /// When the displayed thought would archive if no action is taken.
    public func expiryDate(of thought: Thought) -> Date? {
        engine.expiryDate(of: thought)
    }

    /// The card currently being decided, or `nil` once the session is over.
    public var current: Thought? {
        position < cards.count ? cards[position] : nil
    }

    /// Unreviewed cards in their original urgency order.
    public var pendingCards: [Thought] {
        Array(cards.dropFirst(position))
    }

    /// The return date used by the pause action.
    public var returnDate: Date {
        clock.now.addingTimeInterval(snoozeDays * .day)
    }

    /// The pause interval in the action's label.
    public var hideTitle: String {
        let count = snoozeDays.formatted(.number.precision(.fractionLength(0 ... 1)))
        return "Hide for \(count) \(snoozeDays == 1 ? "day" : "days")"
    }

    /// Whether every card has been dealt with.
    public var isFinished: Bool {
        hasLoaded && position >= cards.count
    }

    /// Which card this is, and how many there are.
    public var progress: (position: Int, total: Int) {
        (min(position + 1, cards.count), cards.count)
    }

    /// When the current card would archive if nothing were decided.
    ///
    /// Shown on the card so the decision has a stake: this is why it is being raised.
    public var currentExpiry: Date? {
        current.flatMap { engine.expiryDate(of: $0) }
    }

    /// Whether the current card can carry an ambient sharpening question.
    public var currentAcceptsAmbientQuestion: Bool {
        current?.canEditContent == true && current?.canBeSharpened == true && current?.sharpening == nil
    }

    /// Builds the session.
    public func load() async {
        let everything = await (try? repository.thoughts(in: .live)) ?? []
        cards = selector.select(from: everything, at: clock.now)
        position = 0
        tally = Tally()
        hasLoaded = true
    }

    /// Keeps undecided cards current without restarting the review or its tally.
    public func observeChanges() async {
        let stream = changes.changes
        for await _ in stream {
            await refreshPending()
        }
    }

    /// Reconciles remaining cards with the latest stored state.
    func refreshPending() async {
        guard hasLoaded, let latest = try? await repository.thoughts(in: .live) else { return }
        let eligible = Dictionary(
            selector.select(from: latest, at: clock.now).map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let decided = Array(cards.prefix(position))
        cards = decided + cards.dropFirst(position).compactMap { eligible[$0.id] }
    }

    /// Fetches a question to attach to the current idea card, if it can take one.
    public func loadAmbientQuestion() async {
        ambientQuestion = nil
        ambientAnswer = ""
        guard let thought = current, currentAcceptsAmbientQuestion else { return }

        let questions = await intelligence.interviewQuestions(for: thought.body)
        // Only attach it if we are still on the same card: the model is slow enough to outlast
        // a decision.
        guard current?.id == thought.id else { return }
        ambientQuestion = questions.first
    }

    /// Keeps the current thought and restores its freshness.
    public func act(id: Thought.ID? = nil) async {
        guard var thought = pendingThought(id: id) else { return }
        thought.markActed(at: clock.now)
        await decide(thought, as: .acted)
    }

    /// Sets the current thought aside for another week.
    public func snooze(id: Thought.ID? = nil) async {
        guard var thought = pendingThought(id: id) else { return }
        thought.snooze(until: clock.now.addingTimeInterval(snoozeDays * .day), at: clock.now)
        await decide(thought, as: .snoozed)
    }

    /// Lets the current thought go to the archive. Nothing is destroyed.
    public func archive(id: Thought.ID? = nil) async {
        guard var thought = pendingThought(id: id) else { return }
        guard thought.canEditContent else {
            lastError = ListSharingError.readOnly.localizedDescription
            return
        }
        thought.archive(at: clock.now)
        await decide(thought, as: .archived)
    }

    /// Records an answer to the ambient question, which counts as acting on the thought.
    ///
    /// The answer is stored as the beginning of a sharpening interview, so the work done here
    /// carries over to the Sharpen screen rather than being thrown away.
    public func answerAmbientQuestion() async {
        let trimmed = ambientAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let question = ambientQuestion, var thought = current else { return }

        thought.beginSharpening(prompts: [question], at: clock.now)
        if let asked = thought.sharpening?.questions.first {
            thought.answerSharpening(trimmed, to: asked.id, at: clock.now)
        }
        await decide(thought, as: .acted)
    }

    private func pendingThought(id: Thought.ID?) -> Thought? {
        guard let id else { return current }
        return pendingCards.first { $0.id == id }
    }

    /// Writes a decision back and moves to the next card.
    /// - Parameters:
    ///   - thought: The thought as decided.
    ///   - outcome: What was decided.
    private func decide(_ thought: Thought, as outcome: Outcome) async {
        guard !isDeciding, let index = cards.firstIndex(where: { $0.id == thought.id }),
              index >= position else { return }
        let wasCurrent = current?.id == thought.id
        isDeciding = true
        defer { isDeciding = false }
        do {
            try await repository.update(thought)
            lastError = nil
        } catch {
            lastError = (error as? ListSharingError)?.localizedDescription ?? "This decision couldn’t be saved. Try again."
            return
        }
        if let latestIndex = cards.firstIndex(where: { $0.id == thought.id }), latestIndex >= position {
            cards.remove(at: latestIndex)
        }
        cards.insert(thought, at: position)

        switch outcome {
        case .acted: tally.acted += 1
        case .snoozed: tally.snoozed += 1
        case .archived: tally.archived += 1
        }

        if wasCurrent {
            ambientQuestion = nil
            ambientAnswer = ""
        }
        position += 1
        changes.notify()
    }
}
