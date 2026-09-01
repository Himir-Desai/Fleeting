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
        .navigationTitle("Review")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .task { await model.load() }
            .task(id: model.current?.id) { await model.loadAmbientQuestion() }
    }

    /// Shown when nothing is fading or repeatedly deferred.
    private var emptyState: some View {
        EmptyState(
            symbol: "checkmark.seal",
            title: "Nothing needs a decision",
            message: "Everything is either fresh or already dealt with."
        )
        .accessibilityIdentifier("review.empty")
    }

    /// One card, with the decisions available for it.
    @ViewBuilder
    private var session: some View {
        if let thought = model.current {
            VStack(alignment: .leading, spacing: Spacing.loose) {
                progress

                // The card sits between the progress and the decisions rather than at the top:
                // one card alone against a screen of empty page reads as a loading state.
                Spacer(minLength: Spacing.loose)

                Card(elevation: .floating) {
                    VStack(alignment: .leading, spacing: Spacing.regular) {
                        Text(thought.body)
                            .font(Typography.capture)
                            .foregroundStyle(Palette.ink)
                            .accessibilityIdentifier("review.card")

                        if let expiry = model.currentExpiry {
                            Label {
                                Text("archives \(expiry, format: .relative(presentation: .named))")
                            } icon: {
                                Image(systemName: "clock")
                            }
                            .font(Typography.caption)
                            .foregroundStyle(Palette.fading)
                            .accessibilityIdentifier("review.expiry")
                        }

                        if let question = model.ambientQuestion {
                            Divider().overlay(Palette.separator)
                            ambientPrompt(question)
                        }
                    }
                }

                Spacer(minLength: Spacing.loose)
                decisions
            }
            .padding(Spacing.loose)
        }
    }

    /// How far through the session the user is, said in words and drawn as a bar.
    ///
    /// The bar is what makes the session feel finite from the first card, which is the whole
    /// argument for capping it at seven (ADR-0007).
    private var progress: some View {
        VStack(alignment: .leading, spacing: Spacing.snug) {
            SectionLabel("\(model.progress.position) of \(model.progress.total)")
                .accessibilityIdentifier("review.progress")
                .accessibilityLabel(
                    "Thought \(model.progress.position) of \(model.progress.total)"
                )

            ProgressView(
                value: Double(model.progress.position),
                total: Double(max(model.progress.total, 1))
            )
            .tint(Palette.accentText)
            .accessibilityHidden(true)
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

            Button("Answer and keep") {
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

    /// Act, snooze, or let go.
    ///
    /// Three buttons side by side stop fitting well before the largest type size, so the row
    /// becomes a column when it has to.
    private var decisions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.regular) {
                letGoButton
                snoozeButton
                Spacer()
                keepButton
            }
            VStack(alignment: .leading, spacing: Spacing.snug) {
                keepButton
                snoozeButton
                letGoButton
            }
        }
        .font(Typography.body)
    }

    /// Archives the thought. All three are real decisions, so all three read as buttons; only the
    /// emphasis differs, because keeping is the one that costs nothing.
    private var letGoButton: some View {
        Button("Let go") { Task { await model.drop() } }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .tint(Palette.inkMuted)
            .accessibilityIdentifier("review.drop")
            .accessibilityHint("Moves this to the archive. Nothing is deleted.")
    }

    /// Holds the thought at full freshness for a week.
    private var snoozeButton: some View {
        Button("Snooze") { Task { await model.snooze() } }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .tint(Palette.inkMuted)
            .accessibilityIdentifier("review.snooze")
            .accessibilityHint("Holds this at full freshness for a week")
    }

    /// Resets the thought's freshness.
    private var keepButton: some View {
        Button("Keep") { Task { await model.act() } }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .tint(Palette.accent)
            .accessibilityIdentifier("review.act")
            .accessibilityHint("Resets how fresh this thought is")
    }

    /// What the session decided, and a way out.
    private var summary: some View {
        VStack(spacing: Spacing.loose) {
            VStack(spacing: Spacing.regular) {
                Image(systemName: "checkmark.seal.fill")
                    .font(Typography.symbol)
                    .foregroundStyle(Palette.accentText)
                    .accessibilityHidden(true)

                Text("That's the lot")
                    .font(Typography.display)
                    .foregroundStyle(Palette.ink)

                Text(summaryLine)
                    .font(Typography.body)
                    .foregroundStyle(Palette.inkMuted)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("review.summary")
            }

            Button("Back to capture") { dismiss() }
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
            parts.append("kept \(tally.acted)")
        }
        if tally.snoozed > 0 {
            parts.append("snoozed \(tally.snoozed)")
        }
        if tally.dropped > 0 {
            parts.append("let go of \(tally.dropped)")
        }
        guard !parts.isEmpty else { return "Nothing decided." }
        return "You " + parts.joined(separator: ", ") + "."
    }
}
