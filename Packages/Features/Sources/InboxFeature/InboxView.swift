import Core
import DesignSystem
import SwiftUI

/// The list of live thoughts: a summary line, a row of kind filters, and the thoughts themselves.
///
/// Review sits below the summary; filtering and Settings sit side by side in the toolbar.
public struct InboxView: View {
    @State private var model: InboxModel

    private let isListDestination: Bool
    private let storageIsDegraded: Bool
    private let changes: any ThoughtChangeObserving
    private let onSettings: () -> Void
    private let onReview: () -> Void
    private let onEditList: (ThoughtList) -> Void
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
    ///   - onSettings: Opens app settings from the toolbar.
    public init(
        model: InboxModel,
        changes: any ThoughtChangeObserving,
        storageIsDegraded: Bool = false,
        isListDestination: Bool = false,
        onReview: @escaping () -> Void,
        onOpen: @escaping (Thought) -> Void,
        onSettings: @escaping () -> Void = {},
        onEditList: @escaping (ThoughtList) -> Void = { _ in }
    ) {
        _model = State(initialValue: model)
        self.changes = changes
        self.isListDestination = isListDestination
        self.storageIsDegraded = storageIsDegraded
        self.onReview = onReview
        self.onOpen = onOpen
        self.onSettings = onSettings
        self.onEditList = onEditList
    }

    public var body: some View {
        Group {
            if isListDestination, selectedList == nil {
                Palette.surface
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier("lists.emptyDestination")
            } else {
                VStack(spacing: 0) {
                    header
                    list
                }
            }
        }
        .background(Palette.surface)
        .pageHeading(
            selectedList?.name ?? (isListDestination ? "Lists" : "Thoughts"),
            titleIdentifier: selectedList == nil ? "inbox.heading" : "inbox.selectedList"
        ) {
            ToolbarPill {
                if let selectedList, !selectedList.isBuiltIn {
                    Button { onEditList(selectedList) } label: { Image(systemName: "pencil") }
                        .accessibilityLabel("Edit \(selectedList.name)")
                        .accessibilityIdentifier("inbox.editSelectedList")
                }
                InboxFilterMenu(filter: $model.filter)
                Button(action: onSettings) { Image(systemName: "gearshape") }
                    .accessibilityLabel("Settings")
                    .accessibilityIdentifier("app.settings")
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

    private var selectedList: ThoughtList? {
        model.lists.first { $0.id == model.selectedListID }
    }

    /// The summary line, pinned above the scrolling list.
    ///
    /// The kind chips that used to live here have moved into the toolbar (ADR-0036): urgency is
    /// the list's axis now, and a permanent row of chips arguing for a different one made the
    /// screen ask two questions at once.
    private var header: some View {
        masthead
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.loose)
            .padding(.top, Spacing.snug)
            .padding(.bottom, Spacing.regular)
    }

    /// One honest line about the state of the pile, with a review invitation underneath.
    private var masthead: some View {
        VStack(alignment: .leading, spacing: Spacing.regular) {
            if let sharing = selectedList?.sharing {
                Label(
                    sharing.role == .viewer ? "Shared · View only" : "Shared · Manual archiving",
                    systemImage: "person.2"
                )
                .font(Typography.caption).foregroundStyle(Palette.accentText)
            }
            if let selectedList, !selectedList.description.isEmpty {
                Text(selectedList.description)
                    .font(Typography.subtitle)
                    .foregroundStyle(Palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if model.lastError != nil {
                Text("Thoughts couldn’t be updated. Try again.")
                    .font(Typography.caption).foregroundStyle(Palette.fading)
                    .accessibilityIdentifier("inbox.error")
            }
            Text(summaryLine)
                .font(Typography.subtitle)
                .foregroundStyle(Palette.inkMuted)
                .accessibilityIdentifier("inbox.summary")

            if model.reviewCount >= 1 {
                Button(action: onReview) {
                    Label(
                        "\(model.reviewCount) \(model.reviewCount == 1 ? "thought" : "thoughts") to review",
                        systemImage: "clock.arrow.circlepath"
                    )
                    .font(Typography.subtitle)
                    .foregroundStyle(Palette.accentText)
                }
                .buttonStyle(PressFeedbackStyle())
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
                        sectionHeader(for: section.band)
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

    /// One urgency section's heading.
    ///
    /// The most urgent band is warmed and weighted; the others stay quiet. Three identically grey
    /// headings said the sections differ without saying that one of them matters (ADR-0041). The
    /// generous top inset is what separates one group from the next — inside a section the cards
    /// sit close, between sections the page breathes.
    /// - Parameter band: The band being introduced.
    /// - Returns: The header row.
    private func sectionHeader(for band: UrgencyBand) -> some View {
        Group {
            if band == .goingSoon {
                SectionLabel(band.title, tint: Palette.fading, weight: .bold)
            } else {
                SectionLabel(band.title)
            }
        }
        .textCase(nil)
        .listRowInsets(
            EdgeInsets(
                top: Spacing.section,
                leading: Spacing.loose,
                bottom: Spacing.snug,
                trailing: Spacing.loose
            )
        )
        .accessibilityIdentifier("inbox.section.\(band.rawValue)")
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
            if model.selectedListID != nil {
                EmptyState(
                    symbol: "list.bullet",
                    title: "No thoughts here",
                    message: "Choose this list when capturing a thought."
                )
            } else {
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
