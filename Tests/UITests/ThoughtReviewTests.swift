import XCTest

/// Explicit thought-review decisions and the shared daily-review card presentation.
@MainActor
final class ThoughtReviewTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-store", "--seed-demo"]
        app.launch()
        XCTAssertTrue(app.goToReview())
        return app
    }

    private func reveal(_ element: XCUIElement, app: XCUIApplication) {
        for _ in 0 ..< 10 {
            if element.exists, element.isHittable {
                return
            }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }

    func testExplicitLabelsAndTaskReviewStyle() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["A fresh start"].exists)
        let keep = app.buttons["review.act"]
        let hide = app.buttons["review.snooze"]
        let archive = app.buttons["review.archive"]
        XCTAssertEqual(keep.label, "Keep active")
        XCTAssertEqual(hide.label, "Hide for 7 days")
        XCTAssertEqual(archive.label, "Archive")
        reveal(archive, app: app)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Thought review shares daily review cards"
        shot.lifetime = .keepAlways
        add(shot)
        let thought = app.staticTexts["review.card"].label
        archive.tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.chooseFilter("Archived"))
        let stored = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", thought)).firstMatch
        XCTAssertTrue(stored.waitForExistence(timeout: 5), "Archive preserves the thought")
    }

    func testHidePausesVisibilityAndKeepActiveLeavesThoughtVisible() {
        let app = launch()
        let kept = app.staticTexts["review.card"].label
        reveal(app.buttons["review.act"], app: app)
        app.buttons["review.act"].tap()
        XCTAssertTrue(app.staticTexts["review.card"].waitForExistence(timeout: 5))
        let hidden = app.staticTexts["review.card"].label
        reveal(app.buttons["review.snooze"], app: app)
        app.buttons["review.snooze"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.chooseFilter("All"))
        let keptRow = app.buttons.matching(NSPredicate(
            format: "identifier == 'row.open' AND label CONTAINS %@",
            kept
        )).firstMatch
        reveal(keptRow, app: app)
        XCTAssertTrue(keptRow.exists)
        let hiddenRow = app.buttons.matching(NSPredicate(
            format: "identifier == 'row.open' AND label CONTAINS %@",
            hidden
        )).firstMatch
        XCTAssertFalse(hiddenRow.exists)
    }
}
