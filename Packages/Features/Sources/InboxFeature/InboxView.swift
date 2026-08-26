import Core
import DesignSystem
import SwiftUI

/// The list of live thoughts, newest first, faded by freshness.
///
/// Reachable from capture but never before it: this screen is always a destination, never a
/// starting point (ADR-0008).
public struct InboxView: View {
    @State private var model: InboxModel
    @Environment(\.dismiss) private var dismiss
    private let changes: any ThoughtChangeObserving
    private let onOpenArchive: () -> Void
    private let onOpenSettings: () -> Void

    /// Creates the inbox.
    /// - Parameters:
    ///   - model: State and rules for the list, built by the composition root.
    ///   - onOpenArchive: Called when the user asks to see archived thoughts. The inbox declares
    ///     the intent; the app layer decides what it opens.
    ///   - onOpenSettings: Called when the user asks for settings.
    ///   - changes: Watched so a classification landing while the list is open is reflected.
    public init(
        model: InboxModel,
        changes: any ThoughtChangeObserving,
        onOpenArchive: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        _model = State(initialValue: model)
        self.changes = changes
        self.onOpenArchive = onOpenArchive
        self.onOpenSettings = onOpenSettings
    }

    public var body: some View {
        List {
            ForEach(model.thoughts) { thought in
                HStack(spacing: Spacing.regular) {
                    kindControl(for: thought)

                    NavigationLink {
                        ThoughtEditor(thought: thought) { revised in
                            Task { await model.revise(thought, to: revised) }
                        }
                    } label: {
                        ThoughtRow(
                            thought: thought,
                            freshness: model.freshness(of: thought),
                            expiresAt: model.expiryDate(of: thought)
                        )
                    }
                }
                .listRowBackground(Palette.raised)
                .listRowSeparatorTint(Palette.ink.opacity(0.12))
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    typeAction(for: thought)
                    Button {
                        Task { await model.snooze(thought, forDays: 7) }
                    } label: {
                        Label("Snooze", systemImage: "moon.zzz")
                    }
                    .tint(Palette.inkMuted)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        Task { await model.delete(thought) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Button {
                        Task { await model.archive(thought) }
                    } label: {
                        Label("Archive", systemImage: "archivebox")
                    }
                    .tint(Palette.inkMuted)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Palette.surface)
        .overlay {
            if model.hasLoaded, model.thoughts.isEmpty {
                Text("Nothing live right now.")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.inkMuted)
                    .accessibilityIdentifier("inbox.empty")
            }
        }
        .navigationTitle("Thoughts")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar {
                // Capture must never be more than one tap away. A swipe-down works, but a
                // gesture nobody can see is not a way back.
                ToolbarItem(placement: .cancellationAction) {
                    Button("Capture") { dismiss() }
                        .accessibilityIdentifier("inbox.done")
                        .accessibilityLabel("Back to capture")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: onOpenArchive) {
                        Image(systemName: "archivebox")
                    }
                    .accessibilityIdentifier("inbox.archive")
                    .accessibilityLabel("Open archive")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: onOpenSettings) {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityIdentifier("inbox.settings")
                    .accessibilityLabel("Open settings")
                }
            }
            .refreshable { await model.load() }
            .task { await model.load() }
            .task {
                // Classification finishes after capture has moved on; without this the list
                // would show "Unsorted" until the user closed and reopened it.
                for await _ in changes.changes {
                    await model.load()
                }
            }
    }

    /// The kind control for a row: one tap opens it, one more corrects the kind.
    ///
    /// A visible control rather than a long-press, so the correction is discoverable.
    /// - Parameter thought: The thought whose kind may be changed.
    /// - Returns: A menu showing the current kind.
    private func kindControl(for thought: Thought) -> some View {
        Menu {
            Picker("Kind", selection: kindBinding(for: thought)) {
                ForEach(ThoughtKind.allCases, id: \.self) { kind in
                    Label(KindGlyph.label(for: kind), systemImage: KindGlyph.name(for: kind))
                        .tag(kind)
                }
            }
        } label: {
            Image(systemName: KindGlyph.name(for: thought.kind))
                .font(Typography.body)
                .foregroundStyle(
                    thought.kind == .unsorted ? Palette.inkMuted : Palette.accent
                )
                .frame(width: 32, height: 32)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("row.kind")
        .accessibilityLabel("Kind: \(KindGlyph.label(for: thought.kind))")
    }

    /// A binding that writes a kind correction straight through to the model.
    /// - Parameter thought: The thought being corrected.
    /// - Returns: A binding over the thought's kind.
    private func kindBinding(for thought: Thought) -> Binding<ThoughtKind> {
        Binding(
            get: { thought.kind },
            set: { kind in Task { await model.confirmKind(kind, for: thought) } }
        )
    }

    /// The action that makes sense for a thought's kind, if any.
    ///
    /// A todo can be completed and a habit can be kept. Ideas get their Sharpen action in Phase 4.
    /// - Parameter thought: The thought the action applies to.
    /// - Returns: A swipe action button, or nothing.
    @ViewBuilder
    private func typeAction(for thought: Thought) -> some View {
        switch thought.kind {
        case .todo:
            Button {
                Task { await model.complete(thought) }
            } label: {
                Label("Done", systemImage: "checkmark")
            }
            .tint(Palette.accent)
        case .habit:
            Button {
                Task { await model.markHabitKept(thought) }
            } label: {
                Label("Kept", systemImage: "flame")
            }
            .tint(Palette.accent)
        case .idea, .unsorted:
            EmptyView()
        }
    }
}
