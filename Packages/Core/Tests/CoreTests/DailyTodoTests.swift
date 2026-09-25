@testable import Core
import Foundation
import Testing

@Suite("Daily checklist lifecycle")
struct DailyTodoTests {
    private let today = PlanDay(rawValue: 20_260_922)
    private let yesterday = PlanDay(rawValue: 20_260_921)
    private let now = Date(timeIntervalSince1970: 1_790_102_400)

    @Test("overdue tasks await review without automatically moving or expiring")
    func reviewFirst() {
        let task = DailyTodo(text: "Send draft", createdAt: now, day: yesterday)
        #expect(task.needsReview(on: today))
        #expect(task.day == yesterday)
        #expect(task.needsReview(on: PlanDay(rawValue: 20_261_005)))
    }

    @Test("unfinished tasks jump to today even after several missed days, without duplicating")
    func carryForward() {
        var task = DailyTodo(text: "Send draft", createdAt: now, day: yesterday)
        let id = task.id
        let later = PlanDay(rawValue: 20_261_005)
        task.apply(.carryForward, today: later, at: now)
        task.apply(.carryForward, today: later, at: now)
        #expect(task.day == later)
        #expect(task.id == id)
        #expect(!task.needsReview(on: later))
        #expect(!task.isDone)
    }

    @Test("completion stays on the original day and repeated widget taps are idempotent")
    func completedHistory() {
        var task = DailyTodo(text: "Send draft", createdAt: now, day: yesterday)
        task.apply(.finish, today: today, at: now)
        task.apply(.finish, today: today, at: now.addingTimeInterval(60))
        task.apply(.carryForward, today: today, at: now)
        #expect(task.day == yesterday)
        #expect(task.completedAt == now)
        #expect(!task.needsReview(on: today))
        task.apply(.reopen, today: today, at: now)
        #expect(task.needsReview(on: today))
    }

    @Test("tomorrow's tasks cannot be carried backward to today")
    func futureTask() {
        let tomorrow = PlanDay(rawValue: 20_260_923)
        var task = DailyTodo(text: "Pack bag", createdAt: now, day: tomorrow)
        task.apply(.carryForward, today: today, at: now)
        #expect(task.day == tomorrow)
        #expect(!task.needsReview(on: today))
    }

    @Test("calendar dates survive time zones and daylight-saving boundaries")
    func calendarDays() throws {
        let zone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let otherZone = try #require(TimeZone(identifier: "Asia/Tokyo"))
        let spring = PlanDay(rawValue: 20_260_308)
        let next = PlanDay(rawValue: 20_260_309)
        let start = try #require(spring.date(timeZone: zone))
        #expect(try #require(next.date(timeZone: zone)).timeIntervalSince(start) == 23 * 3600)
        #expect(try PlanDay(#require(spring.date(timeZone: otherZone)), timeZone: otherZone) == spring)
        #expect(PlanDay(rawValue: 20_260_230).date(timeZone: zone) == nil)
    }
}
