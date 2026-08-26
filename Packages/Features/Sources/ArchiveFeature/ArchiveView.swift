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
                VStack(alignment: .leading, spacing: Spacing.snug) {
                    Text(thought.body)
                        .font(Typography.emphasis)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(3)
                    Text("captured \(thought.capturedAt, format: .relative(presentation: .named))")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.inkMuted)
                }
                .padding(.vertical, Spacing.regular)
                .listRowInsets(
                    EdgeInsets(
                        top: 0, leading: Spacing.loose,
                        bottom: 0, trailing: Spacing.loose
                    )
                )
                .listRowSeparator(.hidden)
                // The archive is flat: nothing here is decaying, so nothing here carries a rail.
                .listRowBackground(
                    CardSurface(elevation: .flat)
                        .padding(.horizontal, Spacing.snug)
                        .padding(.vertical, Spacing.tight)
                )
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
                emptyState
            }
        }
        .motion(Motion.decay, value: model.results.map(\.id))
        .searchable(text: $model.query, prompt: "Search everything you've let go")
        .onChange(of: model.query) { Task { await model.search() } }
        .navigationTitle("Archive")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .task { await model.search() }
    }

    /// Shown when the archive has nothing to show, which means two different things.
    private var emptyState: some View {
        EmptyState(
            symbol: model.query.isEmpty ? "archivebox" : "magnifyingglass",
            title: model.query.isEmpty ? "Nothing archived yet" : "No matches",
            message: model.query.isEmpty
                ? """
                Thoughts arrive here when they run out of freshness, or when you set them \
                aside. They stay for good.
                """
                : """
                Nothing here contains that. The archive keeps the words you wrote, so try \
                one of them.
                """
        )
        .accessibilityIdentifier("archive.empty")
    }
}
