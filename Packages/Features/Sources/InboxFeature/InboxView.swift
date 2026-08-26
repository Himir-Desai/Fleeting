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
        VStack(spacing: Spacing.snug) {
            Text("Nothing live right now")
                .font(Typography.title)
                .foregroundStyle(Palette.ink)
            Text(
                """
                Everything you captured has been dealt with or filed away. The archive still \
                has it all.
                """
            )
            .font(Typography.caption)
            .foregroundStyle(Palette.inkMuted)
            .multilineTextAlignment(.center)
        }
        .padding(Spacing.loose)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("inbox.empty")
    }

    /// A quiet line saying thoughts are not reaching disk.
    private var storageWarning: some View {
        HStack(spacing: Spacing.snug) {
            Image(systemName: "exclamationmark.triangle")
            Text("Thoughts aren't being saved to disk. They'll be gone when you close the app.")
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(Typography.caption)
        .foregroundStyle(Palette.fading)
        .padding(.vertical, Spacing.tight)
        .listRowBackground(Palette.raised)
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
                    .foregroundStyle(Palette.accentText)
                Text("\(model.reviewCount) need a decision")
                    .font(Typography.body)
                    .foregroundStyle(Palette.ink)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.inkMuted)
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, Spacing.tight)
        .listRowBackground(Palette.raised)
        .accessibilityIdentifier("inbox.review")
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens a short session to decide what to keep")
    }
}
