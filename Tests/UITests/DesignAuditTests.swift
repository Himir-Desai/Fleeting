import XCTest

/// Exercises every destination and records the app-wide design pass for visual review.
@MainActor
final class DesignAuditTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func snapshot(_ name: String, app: XCUIApplication) {
        // Native glass can finish materializing after XCTest considers the app idle.
        Thread.sleep(forTimeInterval: 0.4)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0 ..< 8 {
            if element.exists, element.isHittable {
                return
            }
            app.swipeUp()
        }
        XCTAssertTrue(element.exists)
        XCTAssertTrue(element.isHittable)
    }

    func testAllDestinations() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-store", "--seed-demo", "--seed-plan"]
        app.launch()
        XCTAssertTrue(app.textFields["capture.field"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["home.habits"].waitForExistence(timeout: 10))
        snapshot("01 Home with habits", app: app)

        XCTAssertTrue(app.goToThoughts())
        XCTAssertTrue(app.buttons["app.settings"].isHittable)
        snapshot("02 Thoughts", app: app)
        app.buttons["row.open"].firstMatch.tap()
        XCTAssertTrue(app.textFields["detail.text"].waitForExistence(timeout: 5))
        snapshot("03 Thought properties", app: app)
        reveal(app.buttons["detail.action.archive"], in: app)
        snapshot("04 Thought actions", app: app)
        app.navigationBars.buttons.element(boundBy: 0).tap()

        XCTAssertTrue(app.chooseFilter("Ideas"))
        let idea = app.buttons
            .matching(
                NSPredicate(
                    format: "identifier == 'row.open' AND label CONTAINS 'newsletter about tools that do one thing'"
                )
            )
            .firstMatch
        reveal(idea, in: app)
        idea.tap()
        let enhance = app.buttons["detail.action.enhance"]
        reveal(enhance, in: app)
        enhance.tap()
        XCTAssertTrue(app.staticTexts["sharpen.title"].waitForExistence(timeout: 15))
        snapshot("05 Sharpened thought", app: app)
        reveal(app.buttons["sharpen.revert"], in: app)
        snapshot("06 Sharpen actions", app: app)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        if app.textFields["detail.text"].exists {
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }

        XCTAssertTrue(app.goToThoughts())
        app.buttons["inbox.review"].tap()
        XCTAssertTrue(app.staticTexts["review.card"].waitForExistence(timeout: 10))
        snapshot("07 Thought review", app: app)
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.tabButton("Plan").tap()
        XCTAssertTrue(app.descendants(matching: .any)["plan.week"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["app.settings"].isHittable)
        snapshot("08 Plan", app: app)
        app.buttons["plan.review"].tap()
        XCTAssertTrue(app.staticTexts["A fresh start"].waitForExistence(timeout: 5))
        snapshot("09 Daily review", app: app)
        app.navigationBars.buttons.element(boundBy: 0).tap()

        XCTAssertTrue(app.goToSettings())
        snapshot("10 Settings", app: app)
        reveal(app.staticTexts["settings.fact.storage"], in: app)
        snapshot("11 Settings about", app: app)
        app.buttons["settings.done"].tap()

        XCTAssertTrue(app.goToThoughts())
        app.tabButton("Lists").tap()
        app.buttons["Edit Lists"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["lists.page"].waitForExistence(timeout: 5))
        snapshot("12 Lists", app: app)
    }

    func testLargestTextSettingsAndDetail() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--reset-store",
            "--seed-demo",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        app.launch()
        XCTAssertTrue(app.goToSettings())
        snapshot("Large type sorting choices", app: app)
        let plus = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Increase'")).firstMatch
        reveal(plus, in: app)
        XCTAssertGreaterThanOrEqual(plus.frame.width, 44)
        XCTAssertGreaterThanOrEqual(plus.frame.height, 44)
        snapshot("Large type lifetime controls", app: app)
        app.buttons["settings.done"].tap()
        XCTAssertTrue(app.goToThoughts())
        XCTAssertTrue(app.buttons["app.settings"].isHittable)
        XCTAssertTrue(app.buttons["inbox.filterMenu"].isHittable)
        snapshot("Large type adaptive Thoughts header", app: app)
        app.buttons["row.open"].firstMatch.tap()
        reveal(app.buttons["detail.type.idea"], in: app)
        XCTAssertTrue(app.buttons["detail.type.todo"].exists)
        XCTAssertTrue(app.buttons["detail.type.habit"].exists)
        snapshot("Large type thought type choices", app: app)
        reveal(app.buttons["detail.action.delete"], in: app)
        XCTAssertTrue(app.buttons["detail.action.enhance"].exists)
        snapshot("Large type thought actions", app: app)
    }

    func testReviewDragTracksWithoutCommittingASmallMovement() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-store", "--seed-demo"]
        app.launch()
        XCTAssertTrue(app.goToReview())
        let card = app.staticTexts["review.card"]
        let original = card.label
        let start = card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 20, dy: 0)))
        XCTAssertEqual(card.label, original)
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 160, dy: 0)))
        let changed = NSPredicate(format: "label != %@", original)
        expectation(for: changed, evaluatedWith: card)
        waitForExpectations(timeout: 10)
    }
}
