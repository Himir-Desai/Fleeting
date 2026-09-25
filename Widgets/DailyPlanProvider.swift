import Core
import Foundation
import Persistence
import WidgetKit

/// A day's tasks and the number of earlier tasks awaiting a decision.
struct DailyPlanEntry: TimelineEntry {
    let date: Date
    let day: PlanDay
    let todos: [DailyTodo]
    let reviewCount: Int
    let isReadable: Bool
    let isShared: Bool
}

/// Reads the shared checklist and schedules the next day using calendar boundaries.
struct DailyPlanProvider: TimelineProvider {
    let daysAhead: Int
    private let clock = SystemClock()

    func placeholder(in _: Context) -> DailyPlanEntry {
        preview(at: clock.now)
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyPlanEntry) -> Void) {
        let now = clock.now
        if context.isPreview {
            completion(preview(at: now))
            return
        }
        let finish = WidgetCompletion(completion)
        Task { await finish(entries(at: now).first ?? unavailable(at: now)) }
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<DailyPlanEntry>) -> Void) {
        let now = clock.now
        let finish = WidgetCompletion(completion)
        Task {
            let entries = await entries(at: now)
            let next = Calendar.autoupdatingCurrent.dateInterval(of: .day, for: now)?.end
                ?? now.addingTimeInterval(3600)
            finish(Timeline(entries: entries, policy: .after(min(next, now.addingTimeInterval(3600)))))
        }
    }

    private func entries(at date: Date) async -> [DailyPlanEntry] {
        guard ModelContainerFactory.isShared,
              let store = try? ModelContainerFactory.store(syncing: false),
              let todos = try? await SwiftDataDailyTodoRepository(modelContainer: store.container).all()
        else { return [unavailable(at: date)] }
        let midnight = Calendar.autoupdatingCurrent.dateInterval(of: .day, for: date)?.end
        return [date, midnight].compactMap(\.self).map { instant in
            let today = PlanDay(instant)
            let day = requestedDay(at: instant)
            return DailyPlanEntry(
                date: instant, day: day, todos: todos.filter { $0.day == day }.sorted {
                    $0.isDone == $1.isDone ? $0.createdAt < $1.createdAt : !$0.isDone
                },
                reviewCount: todos.filter { $0.needsReview(on: today) }.count,
                isReadable: true, isShared: true
            )
        }
    }

    private func requestedDay(at date: Date) -> PlanDay {
        PlanDay(Calendar.autoupdatingCurrent.date(byAdding: .day, value: daysAhead, to: date) ?? date)
    }

    private func unavailable(at date: Date) -> DailyPlanEntry {
        DailyPlanEntry(
            date: date, day: requestedDay(at: date), todos: [], reviewCount: 0,
            isReadable: false, isShared: ModelContainerFactory.isShared
        )
    }

    private func preview(at date: Date) -> DailyPlanEntry {
        let day = requestedDay(at: date)
        return DailyPlanEntry(
            date: date, day: day,
            todos: ["Pick up groceries", "Send the draft", "Go for a walk"].map {
                DailyTodo(text: $0, createdAt: date, day: day)
            },
            reviewCount: 1, isReadable: true, isShared: true
        )
    }
}
