import XCTest

/// Covers Phase 8's performance budget.
///
/// A note on what these can and cannot measure. `XCUIApplication.launch()` includes installing the
/// app, attaching the test runner, and waiting for the accessibility hierarchy to be published,
/// which together cost around three seconds on a simulator whatever the app does — measured
/// against the previous phase's build, which was no faster. So the wall-clock ceiling below is a
/// regression guard, not the product's launch time, and the honest test of the promise is the
/// second one: a full store must not cost more than an empty one.
final class PerformanceTests: XCTestCase {
    /// A ceiling on the harness-inflated launch, set well above the ~3s the harness costs on its
    /// own. It catches work that blocks the field — a migration, a sweep, a store scan — not
    /// milliseconds.
    private let launchCeiling: TimeInterval = 8

    override func setUp() {
        continueAfterFailure = false
    }

    /// Launches and returns how long the capture field took to appear.
    ///
    /// Existence only. Whether the field is *focused* is asserted separately, because these two
    /// tests care about elapsed time and a keyboard animation would be measured as launch cost.
    private func timeToField(
        arguments: [String],
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> TimeInterval {
        let app = XCUIApplication()
        app.launchArguments = arguments

        let started = Date()
        app.launch()
        let field = app.descendants(matching: .any)["capture.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 60), file: file, line: line)
        let elapsed = Date().timeIntervalSince(started)

        app.terminate()
        return elapsed
    }

    func testColdLaunchReachesAFocusedFieldWithinCeiling() {
        let elapsed = timeToField(arguments: ["--reset-store"])
        XCTAssertLessThan(
            elapsed, launchCeiling,
            "cold launch to a usable field took \(String(format: "%.2f", elapsed))s"
        )
    }

    /// That a cold launch lands on a field that is actually ready to be typed into.
    ///
    /// ADR-0008 is the highest-priority constraint in the project, and until now nothing guarded
    /// the half of it that matters. The ceiling test above waits only for the field to *exist*, so
    /// it would pass just as happily against a screen you had to tap before you could write —
    /// which is exactly the two-second tax the app was built to remove.
    func testColdLaunchLandsOnAFocusedFieldWithTheKeyboardUp() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-store"]
        app.launch()

        let field = app.descendants(matching: .any)["capture.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 30), "the capture field never appeared")

        XCTAssertTrue(
            app.keyboards.element.waitForExistence(timeout: 10),
            "a cold launch must land with the keyboard already up (ADR-0008)"
        )
        XCTAssertEqual(
            field.value(forKey: "hasKeyboardFocus") as? Bool, true,
            "the capture field must hold keyboard focus without being tapped (ADR-0008)"
        )
    }

    func testAFullStoreDoesNotSlowTheCapturePath() {
        // Seed once, then measure a launch against the store it left behind.
        _ = timeToField(arguments: ["--reset-store", "--seed-many"])
        let full = timeToField(arguments: [])
        let empty = timeToField(arguments: ["--reset-store"])

        // The sweep, the classification queue and the nudge queue all run after the field is on
        // screen. If any of them moves onto the launch path, four hundred thoughts will show it.
        XCTAssertLessThan(
            full, empty * 1.5 + 1,
            """
            a full store must not delay the field: empty \(String(format: "%.2f", empty))s, \
            four hundred thoughts \(String(format: "%.2f", full))s
            """
        )
    }

    func testAFullInboxScrolls() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-store", "--seed-many"]
        app.launch()
        _ = app.descendants(matching: .any)["capture.field"].waitForExistence(timeout: 60)
        app.goToThoughts()

        // Any seeded row will do. Which one leads is a question for the list's ordering, and the
        // list is grouped by urgency now rather than by capture order (ADR-0036) — this test is
        // about whether four hundred thoughts render and scroll at all.
        let anyRow = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH 'thought number '")
        ).firstMatch
        XCTAssertTrue(
            anyRow.waitForExistence(timeout: 30),
            "a large inbox must still render"
        )

        for _ in 0 ..< 8 {
            app.swipeUp(velocity: .fast)
        }

        XCTAssertTrue(
            app.tabButton("New thought").isHittable,
            "the way back to capture must survive scrolling a long list"
        )
    }
}
