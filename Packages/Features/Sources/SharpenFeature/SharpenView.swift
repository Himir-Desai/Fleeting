import Core
import DesignSystem
import SwiftUI

/// Turns a half-formed idea into a structured one by asking about it first.
///
/// The raw captured text stays visible throughout, so the write-up is always read against what was
/// actually written rather than replacing it.
public struct SharpenView: View {
    @State private var model: SharpenModel
    @FocusState private var isAnswerFocused: Bool

    /// Creates the sharpening screen.
    /// - Parameter model: State for the screen, built by the composition root.
    public init(model: SharpenModel) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        ZStack {
            Palette.surface.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.loose) {
                    originalNote
                    phaseContent
                }
                .padding(Spacing.loose)
            }
        }
        .navigationTitle("Sharpen")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .task { await model.start() }
    }

    /// The captured text, always on screen and never altered.
    private var originalNote: some View {
        VStack(alignment: .leading, spacing: Spacing.tight) {
            Text("What you wrote")
                .font(Typography.caption)
                .foregroundStyle(Palette.inkMuted)
            Text(model.thought.body)
                .font(Typography.body)
                .foregroundStyle(Palette.ink)
                .accessibilityIdentifier("sharpen.original")
        }
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch model.phase {
        case .idle, .preparing:
            working("Working out what to ask…")
        case .interviewing:
            interview
        case .writing:
            working("Putting it together…")
        case .finished:
            result
        case let .failed(message):
            failure(message)
        }
    }

    /// The current question and the field to answer it.
    @ViewBuilder
    private var interview: some View {
        if let question = model.currentQuestion {
            VStack(alignment: .leading, spacing: Spacing.regular) {
                Text("Question \(model.progress.answered + 1) of \(model.progress.total)")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.inkMuted)

                Text(question.prompt)
                    .font(Typography.title)
                    .foregroundStyle(Palette.ink)
                    .accessibilityIdentifier("sharpen.question")

                TextField("Your answer", text: $model.draftAnswer, axis: .vertical)
                    .font(Typography.body)
                    .foregroundStyle(Palette.ink)
                    .tint(Palette.accent)
                    .focused($isAnswerFocused)
                    .accessibilityIdentifier("sharpen.answer")

                Button("Next") {
                    Task { await model.submitAnswer() }
                }
                .buttonStyle(.borderedProminent)
                .tint(Palette.accent)
                .disabled(!model.canSubmit)
                .accessibilityIdentifier("sharpen.next")

                if case let .heuristic(reason) = model.availability {
                    Text(reason.summary)
                        .font(Typography.caption)
                        .foregroundStyle(Palette.inkMuted)
                }
            }
            .onAppear { isAnswerFocused = true }
        }
    }

    /// The finished write-up, plus the quiet way to take it further.
    @ViewBuilder
    private var result: some View {
        if let writeUp = model.writeUp {
            VStack(alignment: .leading, spacing: Spacing.loose) {
                section("The pitch", writeUp.pitch, id: "sharpen.pitch")
                section("Who it's for", writeUp.audience, id: "sharpen.audience")
                section("First step", writeUp.firstStep, id: "sharpen.firstStep")
                section("Biggest risk", writeUp.biggestRisk, id: "sharpen.risk")

                if let prompt = model.escalationPrompt {
                    ShareLink(item: prompt) {
                        Text("Take this further elsewhere")
                            .font(Typography.caption)
                            .foregroundStyle(Palette.inkMuted)
                            .underline()
                    }
                    .accessibilityIdentifier("sharpen.escalate")
                }
            }
        }
    }

    /// One labelled part of the write-up.
    /// - Parameters:
    ///   - title: The heading.
    ///   - body: The content.
    ///   - id: An accessibility identifier.
    /// - Returns: The section.
    private func section(_ title: String, _ body: String, id: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.tight) {
            Text(title)
                .font(Typography.caption)
                .foregroundStyle(Palette.accent)
            Text(body)
                .font(Typography.body)
                .foregroundStyle(Palette.ink)
                .accessibilityIdentifier(id)
        }
    }

    /// A progress state with a cancel that loses nothing.
    /// - Parameter message: What is happening.
    /// - Returns: The view.
    private func working(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.regular) {
            HStack(spacing: Spacing.snug) {
                ProgressView()
                Text(message)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.inkMuted)
            }
            Button("Cancel") { model.cancel() }
                .font(Typography.caption)
                .tint(Palette.inkMuted)
                .accessibilityIdentifier("sharpen.cancel")
        }
    }

    /// A legible failure with a way out.
    /// - Parameter message: What went wrong.
    /// - Returns: The view.
    private func failure(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.regular) {
            Text(message)
                .font(Typography.body)
                .foregroundStyle(Palette.fading)
                .accessibilityIdentifier("sharpen.failure")
            Button("Try again") {
                Task { await model.askForQuestions() }
            }
            .buttonStyle(.bordered)
            .tint(Palette.accent)
            .accessibilityIdentifier("sharpen.retry")
        }
    }
}
