import Core
import DesignSystem
import SwiftUI

/// Explicit decisions for overdue checklist items, separate from the thought review.
public struct DailyReviewView: View {
    @Bindable private var model: PlanModel

    public init(model: PlanModel) {
        self.model = model
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.loose) {
                Text("A fresh start").font(Typography.display)
                Text(
                    "Finished these? Mark them done. Choose Not finished to move a task to today."
                )
                .font(Typography.body).foregroundStyle(Palette.inkMuted)
                if let error = model.error {
                    Text(error).foregroundStyle(Palette.fading)
                    Button("Try again") { Task { await model.load() } }
                }
                if model.pendingReview.isEmpty {
                    Text("All caught up").font(Typography.title)
                        .accessibilityIdentifier("plan.review.empty")
                }
                ForEach(model.pendingReview) { todo in
                    Card {
                        VStack(alignment: .leading, spacing: Spacing.regular) {
                            Text(todo.text).font(Typography.serifBody)
                            if let date = todo.day.date(timeZone: model.calendar.timeZone) {
                                Text(date, format: .dateTime.month(.abbreviated).day())
                                    .font(Typography.caption).foregroundStyle(Palette.inkMuted)
                            }
                            ViewThatFits(in: .horizontal) {
                                HStack { decisions(todo) }
                                VStack(alignment: .leading) { decisions(todo) }
                            }
                            .disabled(model.busyIDs.contains(todo.id))
                        }
                    }
                }
                if !model.reviewedDone.isEmpty {
                    SectionLabel("Finished")
                    ForEach(model.reviewedDone) { todo in
                        PlanTodoRow(todo: todo, disabled: model.busyIDs.contains(todo.id)) {
                            Task { await model.decide(todo, .reopen) }
                        }
                    }
                }
            }
            .padding(Spacing.loose)
        }
        .background(Palette.surface.ignoresSafeArea())
        .motion(Motion.card, value: model.pendingReview.map(\.id))
        .task { await model.load() }
        .refreshable { await model.load() }
    }

    @ViewBuilder private func decisions(_ todo: DailyTodo) -> some View {
        Button("Finished", systemImage: "checkmark") {
            Task { await model.decide(todo, .finish, fromReview: true) }
        }
        .buttonStyle(.borderedProminent)
        .accessibilityIdentifier("plan.review.finish.\(todo.id)")
        Button("Not finished", systemImage: "arrow.right") {
            Task { await model.decide(todo, .carryForward, fromReview: true) }
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("plan.review.carry.\(todo.id)")
    }
}
