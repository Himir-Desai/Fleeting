import Core
import DesignSystem
import SwiftUI

/// The list of live thoughts, newest first, faded by freshness.
///
/// Reachable from capture but never before it: this screen is always a destination, never a
/// starting point (ADR-0008).
public struct InboxView: View {
    @State private var model: InboxModel
    private let onOpenArchive: () -> Void

    /// Creates the inbox.
    /// - Parameters:
    ///   - model: State and rules for the list, built by the composition root.
    ///   - onOpenArchive: Called when the user asks to see archived thoughts. The inbox declares
    ///     the intent; the app layer decides what it opens.
    public init(model: InboxModel, onOpenArchive: @escaping () -> Void) {
        _model = State(initialValue: model)
        self.onOpenArchive = onOpenArchive
    }

    public var body: some View {
        List {
            ForEach(model.thoughts) { thought in
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
                .listRowBackground(Palette.raised)
                .listRowSeparatorTint(Palette.ink.opacity(0.12))
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        Task { await model.snooze(thought, forDays: 7) }
                    } label: {
                        Label("Snooze", systemImage: "moon.zzz")
                    }
                    .tint(Palette.accent)
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
                ToolbarItem(placement: .primaryAction) {
                    Button(action: onOpenArchive) {
                        Image(systemName: "archivebox")
                    }
                    .accessibilityIdentifier("inbox.archive")
                    .accessibilityLabel("Open archive")
                }
            }
            .task { await model.load() }
    }
}
