import Core
import DesignSystem
import SwiftUI

/// Turns a half-formed idea into a structured one by asking about it first.
///
/// The raw captured text stays visible throughout, so the write-up is always read against what was
/// actually written rather than replacing it.
public struct SharpenView: View {
    @State private var model: SharpenModel
    @State private var isConfirmingRevert = false
    @FocusState private var isAnswerFocused: Bool
    @Environment(\.dismiss) private var dismiss

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
        .motion(Motion.commit, value: model.progress.answered)
        .navigationTitle("Sharpen")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .task { await model.start() }
    }

    /// The captured text, always on screen and never altered.
    private var originalNote: some View {
        VStack(alignment: .leading, spacing: Spacing.snug) {
            SectionLabel("What you wrote")
            Text(model.thought.body)
                .font(Typography.quoted)
                .foregroundStyle(Palette.ink)
                .accessibilityIdentifier("sharpen.original")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.inset)
        .background {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .fill(Palette.surfaceSunken)
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
                SectionLabel("Question \(model.progress.answered + 1) of \(model.progress.total)")
                    .accessibilityLabel(
                        "Question \(model.progress.answered + 1) of \(model.progress.total)"
                    )

                Text(question.prompt)
                    // The app asking, not the user speaking, so it stays in the sans (ADR-0037).
                    .font(Typography.subtitle)
                    .foregroundStyle(Palette.ink)
                    .accessibilityIdentifier("sharpen.question")

                TextField("Your answer", text: $model.draftAnswer, axis: .vertical)
                    .font(Typography.body)
                    .foregroundStyle(Palette.ink)
                    .tint(Palette.accentText)
                    .focused($isAnswerFocused)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(Spacing.inset)
                    .background {
                        RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                            .fill(Palette.surfaceSunken)
                    }
                    .accessibilityIdentifier("sharpen.answer")

                Button("Next") {
                    Task { await model.submitAnswer() }
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
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

    /// The developed idea, plus the quiet ways to take it further or undo it.
    @ViewBuilder
    private var result: some View {
        if let writeUp = model.writeUp {
            VStack(alignment: .leading, spacing: Spacing.loose) {
                Card {
                    VStack(alignment: .leading, spacing: Spacing.regular) {
                        SectionLabel("Sharpened")

                        Text(writeUp.title)
                            .font(Typography.writtenTitle)
                            .foregroundStyle(Palette.ink)
                            .accessibilityIdentifier("sharpen.title")

                        // A fragment that has been developed into prose has been growing a while,
                        // so it gets the vine rather than the seedling (ADR-0042).
                        VineRule(leaves: 3)

                        Text(writeUp.detail)
                            .font(Typography.body)
                            .foregroundStyle(Palette.ink)
                            .accessibilityIdentifier("sharpen.detail")
                    }
                }

                HStack(spacing: Spacing.loose) {
                    if let prompt = model.escalationPrompt {
                        ShareLink(item: prompt) {
                            Text("Take this further elsewhere")
                                .font(Typography.caption)
                                .foregroundStyle(Palette.inkMuted)
                                .underline()
                        }
                        .accessibilityIdentifier("sharpen.escalate")
                        .accessibilityLabel("Take this further elsewhere")
                        .accessibilityHint("Shares a prompt about this idea with another app")
                    }

                    Spacer()

                    Button("Revert") { isConfirmingRevert = true }
                        .font(Typography.caption)
                        .tint(Palette.inkMuted)
                        .accessibilityIdentifier("sharpen.revert")
                }
            }
            .confirmationDialog(
                "Revert to your original note?",
                isPresented: $isConfirmingRevert,
                titleVisibility: .visible
            ) {
                Button("Revert", role: .destructive) {
                    Task {
                        if await model.revert() {
                            dismiss()
                        }
                    }
                }
                .accessibilityIdentifier("sharpen.revert.confirm")
                Button("Keep it", role: .cancel) {}
            } message: {
                Text("The title, the paragraph and your answers are removed. Your note itself is untouched.")
            }
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
                .accessibilityHint("Stops without losing any answers you have given")
        }
        .accessibilityElement(children: .contain)
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
            .buttonBorderShape(.capsule)
            .tint(Palette.accentText)
            .accessibilityIdentifier("sharpen.retry")
        }
    }
}
