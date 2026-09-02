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

    /// How tall the card's scroll view is, so the card can be centred in it while it fits and
    /// scroll from the top once it does not.
    @State private var cardArea: CGFloat = 0

    /// How far the card has been dragged, so it follows the thumb before a decision commits.
    @State private var dragOffset: CGSize = .zero

    /// How far a drag must travel before it counts as a decision rather than a fidget.
    private let decisionThreshold: CGFloat = 96

    /// Left lets go, right keeps, up snoozes.
    ///
    /// A gesture is a shortcut, never the only way: every decision it can reach is also a button
    /// in the row below (ADR-0040). Anything short of the threshold springs back and decides
    /// nothing.
    private var decisionDrag: some Gesture {
        DragGesture()
            .onChanged { dragOffset = $0.translation }
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                dragOffset = .zero

                if abs(horizontal) > abs(vertical), abs(horizontal) > decisionThreshold {
                    Task { horizontal > 0 ? await model.act() : await model.drop() }
                } else if -vertical > decisionThreshold {
                    Task { await model.snooze() }
                }
            }
    }

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

                // The card scrolls and the decisions do not. At the largest type sizes the card
                // grows taller than the screen, and in a plain stack it pushed "Let go" off the
                // bottom edge — the decisions are the point of the screen, so they stay put and
                // the card gives way instead.
                ScrollView {
                    Card(elevation: .floating) {
                        VStack(alignment: .leading, spacing: Spacing.regular) {
                            Text(thought.body)
                                .font(Typography.quoted)
                                .foregroundStyle(Palette.ink)
                                .accessibilityIdentifier("review.card")

                            if let expiry = model.currentExpiry {
                                Label {
                                    Text(
                                        "archives \(expiry, format: .relative(presentation: .named))"
                                    )
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
                    // Centred while it fits and scrolled from the top once it does not: one card
                    // pinned to the top of an empty page reads as a loading state, but a card
                    // taller than the screen must start at its first line.
                    .frame(maxWidth: .infinity, minHeight: cardArea, alignment: .center)
                    // A card stack should answer to the thumb. Left lets go, right keeps, up
                    // snoozes — the same three decisions as the row below, so nothing is reachable
                    // only by gesture (ADR-0040).
                    .offset(dragOffset)
                    .gesture(decisionDrag)
                }
                .scrollBounceBehavior(.basedOnSize)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { cardArea = $0 }

                ReviewDecisions(
                    onLetGo: { Task { await model.drop() } },
                    onSnooze: { Task { await model.snooze() } },
                    onKeep: { Task { await model.act() } }
                )
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
