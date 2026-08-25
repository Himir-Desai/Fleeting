import Core
import DesignSystem
import SwiftUI

/// The searchable archive of thoughts that have expired or been set aside.
public struct ArchiveView: View {
    @State private var model: ArchiveModel

    /// Creates the archive.
    /// - Parameter model: State and rules for the archive, built by the composition root.
    public init(model: ArchiveModel) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        List {
            ForEach(model.results) { thought in
                VStack(alignment: .leading, spacing: Spacing.tight) {
                    Text(thought.body)
                        .font(Typography.body)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(3)
                    Text(thought.capturedAt, format: .relative(presentation: .named))
                        .font(Typography.caption)
                        .foregroundStyle(Palette.inkMuted)
                }
                .padding(.vertical, Spacing.tight)
                .listRowBackground(Palette.raised)
                .listRowSeparatorTint(Palette.ink.opacity(0.12))
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        Task { await model.restore(thought) }
                    } label: {
                        Label("Restore", systemImage: "arrow.uturn.backward")
                    }
                    .tint(Palette.accent)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        Task { await model.delete(thought) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Palette.surface)
        .overlay {
            if model.hasLoaded, model.results.isEmpty {
                Text(model.query.isEmpty ? "Nothing archived yet." : "No matches.")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.inkMuted)
                    .accessibilityIdentifier("archive.empty")
            }
        }
        .searchable(text: $model.query, prompt: "Search everything you've let go")
        .onChange(of: model.query) { Task { await model.search() } }
        .navigationTitle("Archive")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .task { await model.search() }
    }
}
