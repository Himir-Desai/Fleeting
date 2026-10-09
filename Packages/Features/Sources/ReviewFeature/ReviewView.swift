import Core
import DesignSystem
import SwiftUI

/// The weekly review: a small, finite stack of thoughts that need a decision.
///
/// Never presented on launch and never required. Skipping it costs nothing except that decay keeps
/// running, which is the point.
public struct ReviewView: View {
    @State private var model: ReviewModel
    @FocusState private var isAnswerFocused: Bool
    @Environment(\.dismiss) private var dismiss
    /// Creates the review.
    /// - Parameter model: State for the session, built by the composition root.
    public init(model: ReviewModel) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        ZStack {
            Palette.surface.ignoresSafeArea()

            if !model.hasLoaded {
                ProgressView()
            } else if model.cards.isEmpty {
                emptyState
            } else if model.isFinished {
                summary
            } else {
                session
            }
        }
        // The stack advancing is the one thing that should feel like movement, and a decision is
        // worth confirming without a banner.
        .motion(Motion.card, value: model.position)
        .sensoryFeedback(.selection, trigger: model.position)
        .keyboardDismissControl(isFocused: isAnswerFocused, identifier: "review.dismissKeyboard") {
            isAnswerFocused = false
        }
        .pageHeading("Review")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .task { await model.load() }
            .task { await model.observeChanges() }
            .task(id: model.current?.id) { await model.loadAmbientQuestion() }
    }

    /// Shown when nothing is fading or repeatedly deferred.
    private var emptyState: some View {
        EmptyState(
            title: "Nothing needs a decision",
            message: "Everything is either fresh or already dealt with."
        )
        .accessibilityIdentifier("review.empty")
    }

    /// The same scrolling card layout used by daily task review.
    private var session: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.loose) {
                Text("A fresh start").font(Typography.display).foregroundStyle(Palette.ink)
                Text(
                    "Keep active refreshes it now. \(model.hideTitle) pauses visibility. Archive saves it in Archived without deleting it."
                )
                .font(Typography.body).foregroundStyle(Palette.inkMuted)
                Text("\(model.tally.total) of \(model.cards.count) reviewed")
                    .font(Typography.caption).foregroundStyle(Palette.inkMuted)
                    .accessibilityIdentifier("review.progress")
                if let error = model.lastError {
                    Text(error).font(Typography.caption).foregroundStyle(Palette.fading)
                        .accessibilityIdentifier("review.error")
                }
                ForEach(model.pendingCards) { thought in
                    thoughtCard(thought)
                        .transition(.opacity)
                }
            }
            .padding(Spacing.loose)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Palette.surface)
        .accessibilityIdentifier("review.list")
    }

    private func thoughtCard(_ thought: Thought) -> some View {
        let isCurrent = model.current?.id == thought.id
        let suffix = isCurrent ? "" : "." + thought.id.uuidString
        return ReviewThoughtCard(
            onArchive: { Task { await model.archive(id: thought.id) } },
            onKeepActive: { Task { await model.act(id: thought.id) } },
            canArchive: thought.canEditContent
        ) {
            VStack(alignment: .leading, spacing: Spacing.regular) {
                Text(thought.body).font(Typography.serifBody).foregroundStyle(Palette.ink)
                    .accessibilityIdentifier("review.card" + suffix)
                Text(thought.capturedAt, format: .dateTime.month(.abbreviated).day())
                    .font(Typography.caption).foregroundStyle(Palette.inkMuted)
                if let expiry = model.expiryDate(of: thought) {
                    Text("Archives \(expiry, format: .relative(presentation: .named))")
                        .font(Typography.caption).foregroundStyle(Palette.fading)
                        .accessibilityIdentifier("review.expiry" + suffix)
                }
                if isCurrent, thought.canEditContent, let question = model.ambientQuestion {
                    Divider().overlay(Palette.separator)
                    ambientPrompt(question)
                }
                ReviewDecisions(
                    hideTitle: model.hideTitle, identifierSuffix: suffix,
                    onArchive: { Task { await model.archive(id: thought.id) } },
                    onHide: { Task { await model.snooze(id: thought.id) } },
                    onKeepActive: { Task { await model.act(id: thought.id) } },
                    canArchive: thought.canEditContent
                )
                .disabled(model.isDeciding)
                Text(
                    "Hidden thoughts return \(model.returnDate, format: .dateTime.month(.abbreviated).day())."
                )
                .font(Typography.caption).foregroundStyle(Palette.inkMuted)
            }
        }
    }

    /// The one question an idea card carries, so sharpening happens as a side effect of reviewing.
    /// - Parameter question: What to ask.
    /// - Returns: The prompt and its field.
    private func ambientPrompt(_ question: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.snug) {
            Text(question)
                .font(Typography.subtitle)
                .foregroundStyle(Palette.accentText)
                .accessibilityIdentifier("review.question")

            TextField("One line is enough", text: $model.ambientAnswer, axis: .vertical)
                .font(Typography.body)
                .foregroundStyle(Palette.ink)
                .tint(Palette.accentText)
                // A vertical field inside a fixed-height card is offered less height than its
                // line needs, so the placeholder is sliced through the middle of its glyphs.
                // Taking the ideal height back stops the card cropping the field.
                .fixedSize(horizontal: false, vertical: true)
                .focused($isAnswerFocused)
                .accessibilityIdentifier("review.answer")

            Button("Save answer & keep active") {
                Task { await model.answerAmbientQuestion() }
            }
            .font(Typography.caption)
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .tint(Palette.accentText)
            .disabled(model.ambientAnswer.trimmingCharacters(in: .whitespaces).isEmpty)
            .accessibilityIdentifier("review.answerSubmit")
        }
    }

    /// What the session decided, and a way out.
    private var summary: some View {
        VStack(spacing: Spacing.loose) {
            VStack(spacing: Spacing.regular) {
                // The session grew something: every kept thought is a thought still alive
                // (ADR-0042).
                GrowingSprout(size: 52)

                Text("That's the lot")
                    .font(Typography.display)
                    .foregroundStyle(Palette.ink)

                Text(summaryLine)
                    .font(Typography.body)
                    .foregroundStyle(Palette.inkMuted)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("review.summary")
            }

            Button("Back to Thoughts") { dismiss() }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .tint(Palette.accent)
                .accessibilityIdentifier("review.finish")
        }
        .padding(Spacing.loose)
        .accessibilityElement(children: .contain)
    }

    /// A sentence describing what was decided.
    private var summaryLine: String {
        let tally = model.tally
        var parts: [String] = []
        if tally.acted > 0 {
            parts.append("kept \(tally.acted) active")
        }
        if tally.snoozed > 0 {
            parts
                .append(
                    "hid \(tally.snoozed) for \(model.snoozeDays.formatted(.number.precision(.fractionLength(0 ... 1)))) days"
                )
        }
        if tally.archived > 0 {
            parts.append("archived \(tally.archived)")
        }
        guard !parts.isEmpty else { return "Nothing decided." }
        return "You " + parts.joined(separator: ", ") + "."
    }
}
