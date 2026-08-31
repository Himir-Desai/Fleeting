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
    @State private var isAdvancedExpanded = false

    /// Whether the first-run explanation has been dismissed by hand. Cleared by `--reset-store`.
    @AppStorage("capture.hintDismissed") private var hintDismissed = false
    @FocusState private var isFieldFocused: Bool
    @Environment(\.dynamicTypeSize) private var typeSize

    /// The diameter of the two round controls in the card, grown to stay a 44pt target.
    @ScaledMetric(relativeTo: .body) private var controlSize: CGFloat = 52

    /// The diameter of a type icon, a little smaller so four of them fit between the two controls.
    @ScaledMetric(relativeTo: .body) private var typeIconSize: CGFloat = 40

    /// The type choices in the row, automatic first, then the three kinds a person picks between.
    private let types: [ThoughtKind?] = [nil, .idea, .todo, .habit]

    /// How tall the writing recess is before any text is in it. Dropped at accessibility sizes,
    /// where the field is already tall enough on its own.
    private var wellHeight: CGFloat {
        typeSize.isAccessibilitySize ? 0 : 132
    }

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
            well

            if model.lastError != nil {
                Text("Couldn't save that. Your text is still here — try again.")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.fading)
                    .accessibilityIdentifier("capture.error")
            }

            // The controls appear once there is something to act on — nothing shows under an
            // empty field, so a cold, untouched capture screen is just the box.
            if model.canSave {
                controls
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
        // Tapping anywhere off the box puts the keyboard away. This is the only way down on a
        // simulator with no touch, and the expected one on device.
        .background {
            Palette.surface
                .ignoresSafeArea()
                .contentShape(.rect)
                .onTapGesture { dismissField() }
        }
        // ADR-0008, the highest-priority constraint in the project: a cold launch lands on a
        // focused field with the keyboard already up. Capture must cost zero taps.
        .task { isFieldFocused = true }
        .motion(Motion.commit, value: model.canSave)
        // The save is the one moment worth confirming, and a haptic does it without taking focus.
        .sensoryFeedback(.success, trigger: model.savedCount)
        .sensoryFeedback(.error, trigger: model.failedCount)
        // A thought that reached storage should be said out loud for anyone not watching the
        // field empty itself.
        .onChange(of: model.savedCount) { _, _ in
            AccessibilityNotification.Announcement("Saved").post()
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

    /// The controls under the box, all inside one card: the advanced toggle and save stay put, and
    /// opening advanced reveals the type icons between them and the expiry wheels below — in the
    /// same card, so the keyboard never leaves and the field stays focused.
    private var controls: some View {
        VStack(alignment: .leading, spacing: Spacing.regular) {
            HStack(spacing: Spacing.snug) {
                advancedButton
                Spacer(minLength: 0)

                if isAdvancedExpanded {
                    ForEach(Array(types.enumerated()), id: \.offset) { _, kind in
                        CaptureTypeIcon(
                            kind: kind,
                            isSelected: model.chosenKind == kind,
                            size: typeIconSize
                        ) { model.chooseKind(kind) }
                    }
                    Spacer(minLength: 0)
                }

                saveButton
            }

            // No wheels for an automatic capture: the app decides the timing too, so only a
            // chosen type shows an expiry.
            if isAdvancedExpanded, model.chosenKind != nil {
                ExpiryWheels(
                    count: Binding(
                        get: { model.expirationCount },
                        set: { model.setExpirationCount($0) }
                    ),
                    unit: Binding(
                        get: { model.expirationUnit },
                        set: { model.setExpirationUnit($0) }
                    )
                )
            }
        }
        .padding(Spacing.inset)
        // A fixed full width, so opening advanced grows the card downward rather than sideways.
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .fill(Palette.raised)
        }
        // Animate the expansion, and the wheels sliding in when a type is chosen, here on the
        // card alone, so the height change never ripples out to the field above it.
        .motion(Motion.commit, value: isAdvancedExpanded)
        .motion(Motion.commit, value: model.chosenKind)
    }

    /// The round toggle that opens and closes the advanced panel.
    ///
    /// Tinted while open or while a type has been chosen, so it is clear the next save will not be
    /// sorted automatically.
    private var advancedButton: some View {
        let isActive = isAdvancedExpanded || model.chosenKind != nil
        return Button {
            isAdvancedExpanded.toggle()
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(Typography.title)
                .foregroundStyle(isActive ? Palette.accentText : Palette.inkMuted)
                .frame(width: controlSize, height: controlSize)
                .background {
                    Circle().fill(isActive ? Palette.accentSoft : Palette.surfaceSunken)
                }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("capture.advanced")
        .accessibilityLabel("Advanced options")
        .accessibilityAddTraits(isAdvancedExpanded ? .isSelected : [])
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

    /// Puts the keyboard away and closes the advanced panel with it.
    private func dismissField() {
        isFieldFocused = false
        isAdvancedExpanded = false
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
