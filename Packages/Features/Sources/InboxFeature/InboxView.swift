import Core
import DesignSystem
import SwiftUI

/// The list of captured thoughts, newest first.
///
/// Reachable from capture but never before it: this screen is always a destination, never a
/// starting point (ADR-0008).
public struct InboxView: View {
    @State private var model: InboxModel

    /// Creates the inbox.
    /// - Parameter model: State and rules for the list, built by the composition root.
    public init(model: InboxModel) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        List {
            ForEach(model.thoughts) { thought in
                NavigationLink {
                    ThoughtEditor(thought: thought) { revised in
                        Task { await model.revise(thought, to: revised) }
                    }
                } label: {
                    ThoughtRow(thought: thought)
                }
            }
            .onDelete { offsets in
                let doomed = offsets.map { model.thoughts[$0] }
                Task {
                    for thought in doomed {
                        await model.delete(thought)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Palette.surface)
        .overlay {
            if model.hasLoaded, model.thoughts.isEmpty {
                Text("Nothing captured yet.")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.inkMuted)
                    .accessibilityIdentifier("inbox.empty")
            }
        }
        .navigationTitle("Thoughts")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .task { await model.load() }
    }
}
