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

    private let storageIsDegraded: Bool
    private let changes: any ThoughtChangeObserving
    private let onOpenArchive: () -> Void
    private let onOpenSettings: () -> Void
    private let onSharpen: (Thought) -> Void
    private let onReview: () -> Void

    /// Creates the inbox.
    /// - Parameters:
    ///   - model: State and rules for the list, built by the composition root.
    ///   - onOpenArchive: Called when the user asks to see archived thoughts. The inbox declares
    ///     the intent; the app layer decides what it opens.
    ///   - onOpenSettings: Called when the user asks for settings.
    ///   - onSharpen: Called when the user wants to develop an idea further.
    ///   - onReview: Called when the user chooses to run a review session.
    ///   - storageIsDegraded: Whether the on-disk store failed to open. Shown as a quiet line
    ///     rather than an alert, because thoughts are about to be lost and silence would be
    ///     worse than the fault.
    ///   - changes: Watched so a classification landing while the list is open is reflected.
    public init(
        model: InboxModel,
        changes: any ThoughtChangeObserving,
        storageIsDegraded: Bool = false,
        onOpenArchive: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onSharpen: @escaping (Thought) -> Void,
        onReview: @escaping () -> Void
    ) {
        _model = State(initialValue: model)
        self.changes = changes
        self.storageIsDegraded = storageIsDegraded
        self.onOpenArchive = onOpenArchive
        self.onOpenSettings = onOpenSettings
        self.onSharpen = onSharpen
        self.onReview = onReview
    }

    public var body: some View {
        List {
            if storageIsDegraded {
                storageWarning
            }

            if model.reviewCount >= 1 {
                reviewInvitation
            }

            ForEach(model.thoughts) { thought in
                InboxListRow(
                    thought: thought,
                    freshness: model.freshness(of: thought),
                    expiresAt: model.expiryDate(of: thought),
                    onEdit: { revised in Task { await model.revise(thought, to: revised) } },
                    onCorrectKind: { kind in Task { await model.confirmKind(kind, for: thought) } },
                    onSnooze: { Task { await model.snooze(thought, forDays: 7) } },
                    onArchive: { Task { await model.archive(thought) } },
                    onDelete: { Task { await model.delete(thought) } },
                    onComplete: { Task { await model.complete(thought) } },
                    onMarkHabitKept: { Task { await model.markHabitKept(thought) } },
                    onSharpen: { onSharpen(thought) }
                )
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Palette.surface)
        .motion(Motion.decay, value: model.thoughts.map(\.id))
        .overlay {
            if model.hasLoaded, model.thoughts.isEmpty {
                emptyState
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

    /// Shown when nothing is live, which is a success rather than a void.
    private var emptyState: some View {
        EmptyState(
            symbol: "wind",
            title: "Nothing live right now",
            message: """
            Everything you captured has been dealt with or filed away. The archive still has \
            it all.
            """
        )
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
        .modifier(NoticeRow())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("inbox.storageWarning")
    }

    /// A quiet, contextual way into the review.
    ///
    /// An invitation sitting in the list rather than a prompt that interrupts: the review is never
    /// imposed, and skipping it costs nothing (ADR-0008).
    private var reviewInvitation: some View {
        Button(action: onReview) {
            HStack(spacing: Spacing.regular) {
                Image(systemName: "checklist")
                    .font(Typography.body)
                    .foregroundStyle(Palette.accentText)
                VStack(alignment: .leading, spacing: Spacing.hairline) {
                    Text("\(model.reviewCount) need a decision")
                        .font(Typography.subtitle)
                        .foregroundStyle(Palette.ink)
                    Text("A short session, then it ends")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.inkMuted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.inkMuted)
            }
            .padding(.vertical, Spacing.regular)
        }
        .buttonStyle(.plain)
        .modifier(NoticeRow(tinted: true))
        .accessibilityIdentifier("inbox.review")
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens a short session to decide what to keep")
    }
}

/// The card treatment shared by the two things that are not thoughts: the storage warning and
/// the review invitation.
///
/// They sit in the same list as the rows, so they have to be inset the same way; a modifier keeps
/// the two of them from drifting apart from each other or from ``InboxListRow``.
private struct NoticeRow: ViewModifier {
    /// Whether the card is drawn on the accent ground rather than the plain raised one.
    var tinted = false

    func body(content: Content) -> some View {
        content
            .listRowInsets(
                EdgeInsets(
                    top: 0, leading: Spacing.loose,
                    bottom: 0, trailing: Spacing.loose
                )
            )
            .listRowSeparator(.hidden)
            .listRowBackground(
                Group {
                    if tinted {
                        RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                            .fill(Palette.accentSoft)
                    } else {
                        CardSurface()
                    }
                }
                .padding(.horizontal, Spacing.snug)
                .padding(.vertical, Spacing.tight)
            )
    }
}
