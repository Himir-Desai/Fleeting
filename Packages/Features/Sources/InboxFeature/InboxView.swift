import Core
import DesignSystem
import SwiftUI

/// The list of live thoughts: a summary line, a row of kind filters, and the thoughts themselves.
///
/// A tab in its own right now, so it carries no back-to-capture or settings controls — those are
/// tabs. Capture is never more than a tab away (ADR-0008).
public struct InboxView: View {
    @State private var model: InboxModel

    private let storageIsDegraded: Bool
    private let changes: any ThoughtChangeObserving
    private let onReview: () -> Void
    private let onOpen: (Thought) -> Void

    /// Creates the inbox.
    /// - Parameters:
    ///   - model: State and rules for the list, built by the composition root.
    ///   - changes: Watched so a classification landing while the list is open is reflected.
    ///   - storageIsDegraded: Whether the on-disk store failed to open. Shown as a quiet line
    ///     rather than an alert, because thoughts are about to be lost and silence would be
    ///     worse than the fault.
    ///   - onReview: Called when the user chooses to run a review session.
    ///   - onOpen: Called when the user taps a thought to open its detail.
    public init(
        model: InboxModel,
        changes: any ThoughtChangeObserving,
        storageIsDegraded: Bool = false,
        onReview: @escaping () -> Void,
        onOpen: @escaping (Thought) -> Void
    ) {
        _model = State(initialValue: model)
        self.changes = changes
        self.storageIsDegraded = storageIsDegraded
        self.onReview = onReview
        self.onOpen = onOpen
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            list
        }
        .background(Palette.surface)
        .navigationTitle("Thoughts")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    InboxFilterMenu(filter: $model.filter)
                }
            }
            .task { await model.load() }
            .task {
                // Classification finishes after capture has moved on; without this the list
                // would show "Unsorted" until the user closed and reopened it.
                for await _ in changes.changes {
                    await model.load()
                }
            }
    }

    /// The summary line, pinned above the scrolling list.
    ///
    /// The kind chips that used to live here have moved into the toolbar (ADR-0036): urgency is
    /// the list's axis now, and a permanent row of chips arguing for a different one made the
    /// screen ask two questions at once.
    private var header: some View {
        masthead
            .padding(.horizontal, Spacing.loose)
            .padding(.top, Spacing.snug)
            .padding(.bottom, Spacing.regular)
    }

    /// One honest line about the state of the pile, with the review entry on the end.
    private var masthead: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.snug) {
            Text(summaryLine)
                .font(Typography.subtitle)
                .foregroundStyle(Palette.inkMuted)
                .accessibilityIdentifier("inbox.summary")

            Spacer(minLength: Spacing.snug)

            if model.reviewCount >= 1 {
                Button(action: onReview) {
                    HStack(spacing: Spacing.tight) {
                        Text("\(model.reviewCount) to decide")
                        Image(systemName: "chevron.right")
                            .font(Typography.caption)
                    }
                    .font(Typography.subtitle)
                    .foregroundStyle(Palette.accentText)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("inbox.review")
                .accessibilityLabel("\(model.reviewCount) need a decision")
                .accessibilityHint("Opens a short session to decide what to keep")
            }
        }
    }

    /// The count of live thoughts, and how many are fading.
    private var summaryLine: String {
        let thoughts = "\(model.liveCount) \(model.liveCount == 1 ? "thought" : "thoughts")"
        return model.fadingCount > 0 ? "\(thoughts) · \(model.fadingCount) fading" : thoughts
    }

    /// The scrolling list: the storage warning if any, then the thoughts.
    ///
    /// Live thoughts are grouped into urgency sections so the list answers "what am I about to
    /// lose?" (ADR-0036). The archive stays one flat run, because a thought with no time left to
    /// run cannot be sorted by how much time it has left.
    private var list: some View {
        List {
            if storageIsDegraded {
                storageWarning
            }

            if model.isShowingArchive {
                ForEach(model.filteredThoughts) { thought in
                    ArchivedListRow(
                        thought: thought,
                        onRestore: { Task { await model.restore(thought) } },
                        onDelete: { Task { await model.delete(thought) } }
                    )
                }
            } else {
                ForEach(model.sections, id: \.band) { section in
                    Section {
                        ForEach(section.thoughts) { thought in
                            liveRow(for: thought)
                        }
                    } header: {
                        SectionLabel(section.band.title)
                            .textCase(nil)
                            .listRowInsets(
                                EdgeInsets(
                                    top: Spacing.regular,
                                    leading: Spacing.loose,
                                    bottom: Spacing.tight,
                                    trailing: Spacing.loose
                                )
                            )
                            .accessibilityIdentifier("inbox.section.\(section.band.rawValue)")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Palette.surface)
        .motion(Motion.decay, value: model.filteredThoughts.map(\.id))
        .overlay {
            if model.hasLoaded, model.filteredThoughts.isEmpty {
                emptyState
            }
        }
        .refreshable { await model.load() }
    }

    /// One live thought's row, with every action it offers.
    /// - Parameter thought: The thought to draw.
    /// - Returns: The row.
    private func liveRow(for thought: Thought) -> some View {
        InboxListRow(
            thought: thought,
            freshness: model.freshness(of: thought),
            expiresAt: model.expiryDate(of: thought),
            onOpen: { onOpen(thought) },
            onSnooze: { Task { await model.snooze(thought, forDays: 7) } },
            onArchive: { Task { await model.archive(thought) } },
            onDelete: { Task { await model.delete(thought) } },
            onComplete: { Task { await model.complete(thought) } },
            onMarkHabitKept: { Task { await model.markHabitKept(thought) } }
        )
    }

    /// Shown when the current view has nothing to show — a cleared inbox, an empty kind, or an
    /// empty archive.
    private var emptyState: some View {
        Group {
            switch model.filter {
            case .archived:
                EmptyState(
                    symbol: "archivebox",
                    title: "Nothing archived yet",
                    message: """
                    Thoughts arrive here when they run out of freshness, or when you set them \
                    aside. They stay for good.
                    """
                )
            case .all:
                EmptyState(
                    symbol: "wind",
                    title: "Nothing live right now",
                    message: """
                    Everything you captured has been dealt with or filed away. The archive still \
                    has it all.
                    """
                )
            case .kind:
                EmptyState(
                    symbol: "line.3.horizontal.decrease",
                    title: "Nothing in this filter",
                    message: "No live thoughts of this kind. Try another chip, or All."
                )
            }
        }
        .accessibilityIdentifier("inbox.empty")
    }

    /// A quiet line saying thoughts are not reaching disk.
    private var storageWarning: some View {
        HStack(spacing: Spacing.regular) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Palette.fading)
            Text("Thoughts aren't being saved to disk. They'll be gone when you close the app.")
                .font(Typography.caption)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, Spacing.regular)
        .listRowInsets(
            EdgeInsets(top: 0, leading: Spacing.loose, bottom: 0, trailing: Spacing.loose)
        )
        .listRowSeparator(.hidden)
        .listRowBackground(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .fill(Palette.accentSoft)
                .padding(.horizontal, Spacing.snug)
                .padding(.vertical, Spacing.tight)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("inbox.storageWarning")
    }
}
