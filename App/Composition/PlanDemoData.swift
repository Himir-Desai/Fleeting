#if DEBUG
    import Core
    import Foundation

    extension AppEnvironment {
        /// Seeds calendar-relative tasks only when explicitly requested by UI tests or previews.
        func seedPlanIfRequested() async {
            guard ProcessInfo.processInfo.arguments.contains("--seed-plan"),
                  let stored = try? await dailyTodos.all(), stored.isEmpty else { return }
            let now = clock.now
            let calendar = Calendar.autoupdatingCurrent
            let samples = [
                ("Send the draft", 0), ("Pick up groceries", 0), ("Pack for tomorrow", 1),
                ("Yesterday finished task", -1), ("Yesterday unfinished task", -1)
            ]
            for (text, offset) in samples {
                guard let date = calendar.date(byAdding: .day, value: offset, to: now) else { continue }
                try? await dailyTodos.add(DailyTodo(text: text, createdAt: now, day: PlanDay(date)))
            }
            dailyChanges.notify()
        }
    }
#endif
