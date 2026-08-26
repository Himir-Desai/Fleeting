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
    /// Whether the one-time explanation has been dismissed. Cleared by `--reset-store` so the
    /// UI tests can see a genuine first launch.
    @AppStorage("capture.hintDismissed") private var hintDismissed = false

    @State private var model: CaptureModel
    @FocusState private var isFieldFocused: Bool
    @Environment(\.dynamicTypeSize) private var typeSize
    private let onBrowse: () -> Void

    /// How tall the writing recess is before any text is in it.
    ///
    /// Deliberately *not* scaled with the type size, and dropped entirely at accessibility sizes:
    /// the field inside is already screen-filling there, and a minimum on top of it pushes the
    /// save control off the bottom once the keyboard is up. `AccessibilityTests` asserts it.
    private var wellHeight: CGFloat {
        typeSize.isAccessibilitySize ? 0 : 132
    }

    /// The browse control's tap target, which has to clear 44pt at every type size.
    @ScaledMetric(relativeTo: .body) private var controlSize: CGFloat = 44

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
                well

                if model.lastError != nil {
                    Text("Couldn't save that. Your text is still here — try again.")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.fading)
                        .accessibilityIdentifier("capture.error")
                }

                if showsHint {
                    FirstRunHint { hintDismissed = true }
                }

                Spacer(minLength: 0)
            }
            .motion(Motion.commit, value: showsHint)
            .padding(.horizontal, Spacing.loose)
            .padding(.top, Spacing.loose)
        }
        .safeAreaInset(edge: .bottom) { actions }
        .task { isFieldFocused = true }
        // The save is the one moment worth confirming, and a haptic does it without taking the
        // focus a banner would.
        .sensoryFeedback(.success, trigger: model.savedCount)
        .sensoryFeedback(.error, trigger: model.failedCount)
        // A thought that reached storage should be said out loud for anyone not watching the
        // field empty itself.
        .onChange(of: model.savedCount) { _, _ in
            AccessibilityNotification.Announcement("Saved").post()
        }
    }

    /// The field, in a recess that reads as somewhere to write rather than a control to fill in.
    ///
    /// At ordinary type sizes it holds a minimum height, so a cold launch lands on something that
    /// is visibly waiting for a thought rather than on a single empty line.
    private var well: some View {
        TextField("What's on your mind?", text: $model.text, axis: .vertical)
            .font(Typography.capture)
            .foregroundStyle(Palette.ink)
            .tint(Palette.accentText)
            .focused($isFieldFocused)
            .accessibilityIdentifier("capture.field")
            .accessibilityLabel("Capture a thought")
            .padding(Spacing.inset)
            .frame(maxWidth: .infinity, minHeight: wellHeight, alignment: .topLeading)
            // A background rather than a sibling in a ZStack: a shape has no size of its own, so
            // as a sibling it takes every point offered and the well swallows the screen.
            .background {
                RoundedRectangle(cornerRadius: Radius.well, style: .continuous)
                    .fill(Palette.surfaceSunken)
            }
            // The whole recess is the tap target, not just the line of text in it.
            .contentShape(.rect(cornerRadius: Radius.well, style: .continuous))
            .onTapGesture { isFieldFocused = true }
    }

    /// Browse and save, the only two controls on the screen.
    ///
    /// Save is the prominent one and browse is a quiet chip, because leaving is never the reason
    /// this screen was opened. Two controls side by side stop fitting well before the largest type
    /// size, so the row becomes a column when it has to — the save control staying reachable at
    /// 60pt type is what `AccessibilityTests` asserts.
    private var actions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.regular) {
                browseButton
                Spacer()
                saveButton
            }
            VStack(spacing: Spacing.regular) {
                saveButton
                browseButton
            }
        }
        .padding(.horizontal, Spacing.loose)
        .padding(.vertical, Spacing.regular)
        .background(Palette.surface)
    }

    /// The way to what has already been captured, drawn as a quiet chip.
    private var browseButton: some View {
        Button(action: onBrowse) {
            Image(systemName: "list.bullet")
                .font(Typography.body)
                .foregroundStyle(Palette.inkMuted)
                .frame(width: controlSize, height: controlSize)
                .background {
                    Circle().fill(Palette.surfaceSunken)
                }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("capture.browse")
        .accessibilityLabel("Browse captured thoughts")
    }

    /// Commits the thought and clears the field, without taking focus.
    private var saveButton: some View {
        Button("Save") {
            Task { await model.save() }
        }
        .font(Typography.title)
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .tint(Palette.accent)
        .disabled(!model.canSave)
        .accessibilityIdentifier("capture.save")
    }

    /// Whether the one-time explanation should be on screen.
    ///
    /// It goes as soon as it is dismissed or as soon as the first thought lands, whichever comes
    /// first: having captured something is proof it was not needed.
    private var showsHint: Bool {
        !hintDismissed && model.savedCount == 0
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
