import Core
import DesignSystem
import SwiftUI

/// The capture screen.
///
/// The root of the app and the whole reason it exists: a cold launch lands here with the field
/// already focused and the keyboard already up. Nothing is presented over it, and nothing about
/// a save can take focus away — the field is never disabled, so the next thought can be typed
/// while the previous one is still being written.
public struct CaptureView: View {
    @State private var model: CaptureModel
    @FocusState private var isFieldFocused: Bool
    private let onBrowse: () -> Void

    /// Creates the capture screen.
    /// - Parameters:
    ///   - model: State and rules for capture, built by the composition root.
    ///   - onBrowse: Called when the user asks to see what they have already captured. Capture
    ///     declares the intent; the app layer decides what it opens, because a feature may not
    ///     import another feature.
    public init(model: CaptureModel, onBrowse: @escaping () -> Void) {
        _model = State(initialValue: model)
        self.onBrowse = onBrowse
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            Palette.surface.ignoresSafeArea()

            VStack(alignment: .leading, spacing: Spacing.regular) {
                TextField("What's on your mind?", text: $model.text, axis: .vertical)
                    .font(Typography.capture)
                    .foregroundStyle(Palette.ink)
                    .tint(Palette.accent)
                    .focused($isFieldFocused)
                    .accessibilityIdentifier("capture.field")
                    .accessibilityLabel("Capture a thought")

                if model.lastError != nil {
                    Text("Couldn't save that. Your text is still here — try again.")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.fading)
                        .accessibilityIdentifier("capture.error")
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.loose)
            .padding(.top, Spacing.section)
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button(action: onBrowse) {
                    Image(systemName: "list.bullet")
                }
                .font(Typography.title)
                .tint(Palette.inkMuted)
                .accessibilityIdentifier("capture.browse")
                .accessibilityLabel("Browse captured thoughts")

                Spacer()
                Button("Save") {
                    Task { await model.save() }
                }
                .font(Typography.title)
                .buttonStyle(.borderedProminent)
                .tint(Palette.accent)
                .disabled(!model.canSave)
                .accessibilityIdentifier("capture.save")
            }
            .padding(.horizontal, Spacing.loose)
            .padding(.vertical, Spacing.snug)
        }
        .task { isFieldFocused = true }
    }
}

#Preview {
    CaptureView(
        model: CaptureModel(
            repository: PreviewRepository(),
            intelligence: PreviewIntelligence(),
            clock: PreviewClock()
        ),
        onBrowse: {}
    )
}

/// Storage that discards everything, so previews need no store.
private actor PreviewRepository: ThoughtRepository {
    func add(_ thought: Thought) async throws {}
    func thoughts(in _: ThoughtScope) async throws -> [Thought] {
        []
    }

    func update(_ thought: Thought) async throws {}
    func delete(id: Thought.ID) async throws {}
}

/// A classifier that decides nothing, so previews need no model.
private struct PreviewIntelligence: IntelligenceService {
    var availability: IntelligenceAvailability {
        .heuristic(reason: .notBuiltIn)
    }

    func classify(_: String) async -> Classification {
        .unknown
    }

    func interviewQuestions(for _: String) async -> [String] {
        []
    }

    func writeUp(
        for _: String,
        answers _: [AnsweredQuestion],
        at _: Date
    ) async -> WriteUp? {
        nil
    }

    func resurfacingLine(for _: String) async -> String? {
        nil
    }
}

/// A clock frozen at a fixed instant, so previews never depend on the system time.
private struct PreviewClock: WallClock {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
}
