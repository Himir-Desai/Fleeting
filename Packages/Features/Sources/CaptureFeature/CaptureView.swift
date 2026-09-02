import Core
import DesignSystem
import SwiftUI

/// The capture screen.
///
/// The reason the app exists, and the tab a cold launch lands on. The field is focused with the
/// keyboard up before anything else happens (ADR-0008). Its controls — advanced options and
/// save — appear once you have started typing, directly beneath the box.
public struct CaptureView: View {
    @State private var model: CaptureModel

    /// Whether the first-run explanation has been dismissed by hand. Cleared by `--reset-store`.
    @AppStorage("capture.hintDismissed") private var hintDismissed = false
    @FocusState private var isFieldFocused: Bool

    /// The diameter of the save control, grown to stay a 44pt target.
    @ScaledMetric(relativeTo: .body) private var controlSize: CGFloat = 52

    /// Creates the capture screen.
    /// - Parameter model: State and rules for capture, built by the composition root.
    public init(model: CaptureModel) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        // The column is the layout root and takes the whole screen, with the page colour behind
        // it. A ZStack over an ignoresSafeArea colour proposed an unstable width, which let the
        // widest row size the whole column — so opening advanced grew the field and card sideways.
        VStack(alignment: .leading, spacing: Spacing.regular) {
            // The text block sits a little down the page rather than jammed against the top
            // margin. With the well gone the placeholder was floating alone at the very top of an
            // otherwise empty screen, which read as a page that had failed to load (ADR-0041).
            Spacer(minLength: 0)
                .frame(height: Spacing.section)

            well

            if model.lastError != nil {
                Text("Couldn't save that. Your text is still here — try again.")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.fading)
                    .accessibilityIdentifier("capture.error")
            }

            // What the last save filed, standing where the words were until it retires itself
            // (ADR-0038). Never a control: it cannot be tapped and nothing waits on it.
            if let receipt = model.receipt {
                CaptureReceiptCard(receipt: receipt)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.96, anchor: .top)
                            .combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                    .id(receipt.id)
            }

            // A line, never a screen: the field stays focused and the keyboard stays up
            // (ADR-0021). Retires itself the moment anything is captured.
            if showsHint {
                FirstRunHint { hintDismissed = true }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.loose)
        .padding(.top, Spacing.loose)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // Something growing on the page, so an almost-empty screen reads as paper rather than as
        // one that failed to load (ADR-0046). Behind the text and out of the way of it: the vine
        // is the page's texture, never a control, and never in front of the field.
        .background(alignment: .bottomTrailing) {
            ClimbingVine(height: 240)
                .padding(.trailing, Spacing.snug)
                .padding(.bottom, Spacing.section)
        }
        // Tapping anywhere off the box puts the keyboard away. This is the only way down on a
        // simulator with no touch, and the expected one on device.
        .background {
            Palette.surface
                .ignoresSafeArea()
                .contentShape(.rect)
                .onTapGesture { dismissField() }
                // Named so a test can put the keyboard away deterministically. The alternative
                // was a tap at a guessed fraction of the screen, which is a point that happens to
                // be background today and lands on a control after the next layout change.
                .accessibilityIdentifier("capture.background")
        }
        // Save sits on the keyboard rather than in the page, so it is always under the thumb and
        // never moves as the thought grows (ADR-0039).
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // Only while the keyboard is up. The bar exists to sit on the keyboard, and with the
            // keyboard down its dismiss control pointed at nothing while stranding a grey slab in
            // the middle of an otherwise quiet page.
            if isFieldFocused {
                controls
            }
        }
        // ADR-0008, the highest-priority constraint in the project: a cold launch lands on a
        // focused field with the keyboard already up. Capture must cost zero taps.
        .task { isFieldFocused = true }
        .motion(Motion.commit, value: model.canSave)
        .motion(Motion.commit, value: model.receipt)
        // The save is the one moment worth confirming, and a haptic does it without taking focus.
        .sensoryFeedback(.success, trigger: model.savedCount)
        .sensoryFeedback(.error, trigger: model.failedCount)
        // A thought that reached storage should be said out loud for anyone not watching the
        // field empty itself.
        .onChange(of: model.savedCount) { _, _ in
            AccessibilityNotification.Announcement("Saved").post()
        }
        // The receipt is a moment, not a state: it retires itself so the screen returns to being
        // nothing but a field, which is what the next thought needs.
        .task(id: model.receipt) {
            guard model.receipt != nil else { return }
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            model.clearReceipt()
        }
    }

    /// The field, in a recess that reads as somewhere to write rather than a control to fill in.
    /// Whether the first-run explanation should show.
    ///
    /// Having captured anything is proof the explanation was not needed, so it retires itself
    /// on the first save as well as on an explicit dismissal (ADR-0021).
    private var showsHint: Bool {
        !hintDismissed && model.savedCount == 0
    }

    /// The field: the page itself, not a box drawn on it.
    ///
    /// No recess and no border. The metaphor is paper, and paper does not have a well cut into it
    /// — the well made the largest thing on the most important screen look like one field on a
    /// form (ADR-0039).
    private var well: some View {
        TextField("What's on your mind?", text: $model.text, axis: .vertical)
            .font(Typography.capture)
            .foregroundStyle(Palette.ink)
            .tint(Palette.accentText)
            .focused($isFieldFocused)
            .accessibilityIdentifier("capture.field")
            .accessibilityLabel("Capture a thought")
            .frame(maxWidth: .infinity, alignment: .topLeading)
            // The whole page is the tap target, not just the line of text on it.
            .contentShape(.rect)
            .onTapGesture { isFieldFocused = true }
    }

    /// The save control, sitting on the keyboard rather than in the page.
    ///
    /// Advanced options are gone: expiry wheels at the moment of capture are a form, and a form is
    /// exactly what principle 1 forbids. Kind and lifetime are both editable in the thought's
    /// detail, which is where a decision about a thought belongs (ADR-0039).
    ///
    /// The bar is always present, even with nothing to save, because it carries the only way to
    /// put the keyboard down. At the accessibility type sizes the keyboard covers the tab bar
    /// completely, and without this the capture screen had no exit at all (ADR-0043).
    private var controls: some View {
        HStack(spacing: Spacing.snug) {
            dismissButton
            Spacer(minLength: 0)
            if model.canSave {
                saveButton
            }
        }
        .padding(.horizontal, Spacing.loose)
        .padding(.vertical, Spacing.regular)
        .background(.bar)
        .motion(Motion.commit, value: model.canSave)
    }

    /// Puts the keyboard away, which is the only way off this screen when the keyboard covers the
    /// tab bar.
    private var dismissButton: some View {
        Button(action: dismissField) {
            Image(systemName: "keyboard.chevron.compact.down")
                .font(Typography.title)
                .foregroundStyle(Palette.inkMuted)
                .frame(width: controlSize, height: controlSize)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("capture.dismissKeyboard")
        .accessibilityLabel("Hide keyboard")
    }

    /// The round save control: a tick that commits the thought and clears the field.
    private var saveButton: some View {
        Button {
            Task { await model.save() }
        } label: {
            Image(systemName: "checkmark")
                .font(Typography.title)
                .foregroundStyle(Palette.raised)
                .frame(width: controlSize, height: controlSize)
                .background {
                    Circle().fill(model.canSave ? Palette.accent : Palette.inkMuted.opacity(0.35))
                }
        }
        .buttonStyle(.plain)
        .disabled(!model.canSave)
        .accessibilityIdentifier("capture.save")
        .accessibilityLabel("Save")
    }

    /// Puts the keyboard away.
    private func dismissField() {
        isFieldFocused = false
    }
}

#Preview {
    CaptureView(
        model: CaptureModel(
            repository: PreviewRepository(),
            intelligence: PreviewIntelligence(),
            clock: PreviewClock()
        )
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
