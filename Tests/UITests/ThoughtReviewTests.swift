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

    func testReviewFromOneListShowsNamedAndUnfiledSources() {
        let app = launch()
        let body = app.staticTexts["review.card"].label
        XCTAssertEqual(app.descendants(matching: .any)["review.sourceList"].firstMatch.label, "List: No list")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let row = app.buttons.matching(NSPredicate(
            format: "identifier == 'row.open' AND label CONTAINS %@", body
        )).firstMatch
        reveal(row, app: app)
        row.tap()
        let selector = app.buttons["detail.list"]
        reveal(selector, app: app)
        selector.tap()
        let choices = app.descendants(matching: .any)["detail.listChoices"]
        XCTAssertTrue(choices.waitForExistence(timeout: 5))
        choices.buttons["Add List"].tap()
        let name = app.textFields["lists.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        let listName = "Forgotten projects and ideas from last spring"
        name.tap()
        name.typeText(listName)
        app.buttons["lists.save"].tap()
        XCTAssertTrue(name.waitForNonExistence(timeout: 5))
        XCTAssertEqual(selector.label, listName)
        app.tabButton("Lists").tap()
        let navigation = app.descendants(matching: .any)["inbox.listChoices"]
        XCTAssertTrue(navigation.waitForExistence(timeout: 5))
        navigation.buttons[listName].tap()
        let invitation = app.buttons["inbox.review"]
        XCTAssertTrue(invitation.waitForExistence(timeout: 5))
        XCTAssertTrue(invitation.label.contains("across all lists"))
        invitation.tap()
        XCTAssertTrue(app.staticTexts["review.scope"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["review.scope"].label, "Thoughts from across all lists")
        let sources = app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH 'review.sourceList'"
        ))
        let listed = sources.matching(NSPredicate(format: "label == %@", "List: " + listName)).firstMatch
        XCTAssertTrue(listed.waitForExistence(timeout: 5))
        reveal(listed, app: app)
        XCTAssertTrue(sources.matching(NSPredicate(format: "label == 'List: No list'")).firstMatch.exists)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Global review identifies source lists"
        shot.lifetime = .keepAlways
        add(shot)
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
