import Core
import DesignSystem
import SwiftUI

/// Edits the raw text of a single captured thought.
///
/// The field is seeded from the stored text and committed only on save, so abandoning the screen
/// leaves the thought exactly as it was.
struct ThoughtEditor: View {
    let thought: Thought
    let onSave: (String) -> Void

    @State private var draft: String
    @Environment(\.dismiss) private var dismiss

    /// Creates the editor.
    /// - Parameters:
    ///   - thought: The thought being edited.
    ///   - onSave: Called with the revised text when the user commits.
    init(thought: Thought, onSave: @escaping (String) -> Void) {
        self.thought = thought
        self.onSave = onSave
        _draft = State(initialValue: thought.body)
    }

    var body: some View {
        ZStack {
            Palette.surface.ignoresSafeArea()
            TextField("", text: $draft, axis: .vertical)
                .font(Typography.body)
                .foregroundStyle(Palette.ink)
                .tint(Palette.accent)
                .accessibilityIdentifier("editor.field")
                .padding(Spacing.loose)
        }
        .navigationTitle("Edit")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(draft)
                        dismiss()
                    }
                    .accessibilityIdentifier("editor.save")
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
    }
}
