import Core
import Foundation
import Observation

/// The week picker, dated checklist and daily review queue.
@MainActor
@Observable
public final class PlanModel {
    public private(set) var todos: [DailyTodo] = []
    public private(set) var today: PlanDay
    public var selectedDay: PlanDay
    public var draft = ""
    public private(set) var error: String?
    public private(set) var hasLoaded = false
    public private(set) var isSaving = false
    public private(set) var busyIDs: Set<UUID> = []
    public private(set) var reviewedDone: [DailyTodo] = []
    public let changes: ThoughtChangeNotifier
    public let calendar: Calendar
    private let repository: any DailyTodoRepository
    private let clock: any WallClock
    private var loadVersion = 0

    public init(
        repository: any DailyTodoRepository, changes: ThoughtChangeNotifier,
        clock: any WallClock, calendar: Calendar = .autoupdatingCurrent
    ) {
        self.repository = repository
        self.changes = changes
        self.clock = clock
        self.calendar = calendar
        let initialDay = PlanDay(clock.now, timeZone: calendar.timeZone)
        today = initialDay
        selectedDay = initialDay
    }

    public var selectedTodos: [DailyTodo] {
        todos.filter { $0.day == selectedDay }
    }

    public var pendingReview: [DailyTodo] {
        todos.filter { $0.needsReview(on: today) }
    }

    public var canAdd: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Seven days in the selected calendar week, respecting the locale's first weekday.
    public var week: [PlanDay] {
        guard let date = selectedDay.date(timeZone: calendar.timeZone),
              let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start else { return [] }
        return (0 ..< 7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: start).map {
                PlanDay($0, timeZone: calendar.timeZone)
            }
        }
    }

    public func shiftWeek(_ offset: Int) {
        guard let date = selectedDay.date(timeZone: calendar.timeZone),
              let next = calendar.date(byAdding: .weekOfYear, value: offset, to: date) else { return }
        selectedDay = PlanDay(next, timeZone: calendar.timeZone)
    }

    public func showToday() {
        selectedDay = PlanDay(clock.now, timeZone: calendar.timeZone)
    }

    /// Refreshes day boundaries and stored tasks without automatically deciding overdue items.
    public func load() async {
        let previousToday = today
        today = PlanDay(clock.now, timeZone: calendar.timeZone)
        if today != previousToday {
            reviewedDone = []
        }
        if selectedDay == previousToday {
            selectedDay = today
        }
        loadVersion += 1
        let version = loadVersion
        do {
            let loaded = try await repository.all()
            guard version == loadVersion else { return }
            todos = loaded.sorted {
                $0.day == $1.day ? $0.createdAt < $1.createdAt : $0.day < $1.day
            }
            reviewedDone = reviewedDone.compactMap { previous in
                loaded.first { $0.id == previous.id && $0.isDone }
            }
            error = nil
            hasLoaded = true
        } catch {
            guard version == loadVersion else { return }
            self.error = "Your checklist couldn’t load. Try again."
            hasLoaded = true
        }
    }

    @discardableResult
    public func add() async -> Bool {
        guard canAdd, !isSaving else { return false }
        isSaving = true
        defer { isSaving = false }
        let original = draft
        let todo = DailyTodo(
            text: draft.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: clock.now, day: selectedDay
        )
        do {
            try await repository.add(todo)
            await load()
            if draft == original {
                draft = ""
            }
            changes.notify()
            return true
        } catch {
            self.error = "This task couldn’t be saved. Your text is still here."
            return false
        }
    }

    /// Records a choice once, leaving failed decisions in place for retry.
    public func decide(_ todo: DailyTodo, _ decision: DailyTodoDecision, fromReview: Bool = false) async {
        guard busyIDs.insert(todo.id).inserted else { return }
        defer { busyIDs.remove(todo.id) }
        do {
            let now = clock.now
            let updated = try await repository.decide(
                id: todo.id, decision: decision, today: PlanDay(now, timeZone: calendar.timeZone), at: now
            )
            if fromReview, updated.isDone {
                reviewedDone.removeAll { $0.id == updated.id }
                reviewedDone.append(updated)
            } else {
                reviewedDone.removeAll { $0.id == updated.id }
            }
            await load()
            changes.notify()
        } catch { self.error = "That change couldn’t be saved. Please try again." }
    }

    public func delete(_ todo: DailyTodo) async {
        guard busyIDs.insert(todo.id).inserted else { return }
        defer { busyIDs.remove(todo.id) }
        do {
            try await repository.delete(id: todo.id)
            reviewedDone.removeAll { $0.id == todo.id }
            await load()
            changes.notify()
        } catch { self.error = "This task couldn’t be deleted. Please try again." }
    }
}
