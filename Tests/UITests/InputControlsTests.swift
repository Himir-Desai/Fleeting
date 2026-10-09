import XCTest

/// Keyboard dismissal across every editing flow, including pushed pages and stacked sheets.
@MainActor
final class InputControlsTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testPlanAndThoughtUseTheSameKeyboardControl() {
        let app = launch()
        app.tabButton("Plan").tap()
        let task = app.textFields["plan.input"]
        XCTAssertTrue(task.waitForExistence(timeout: 10))
        task.tap()
        task.typeText("An unfinished task")
        dismissKeyboard("plan.dismissKeyboard", app: app)
        XCTAssertEqual(task.value as? String, "An unfinished task")
        XCTAssertTrue(app.goToThoughts())
        app.buttons["row.open"].firstMatch.tap()
        let thought = app.textFields["detail.text"]
        XCTAssertTrue(thought.waitForExistence(timeout: 5))
        thought.tap()
        thought.typeText(" revision")
        let revised = thought.value as? String
        dismissKeyboard("detail.dismissKeyboard", app: app)
        XCTAssertEqual(thought.value as? String, revised)
        XCTAssertTrue(app.buttons["detail.type.todo"].exists)
        screenshot("Thought keyboard control and round types", app: app)
    }

    func testSharpenUsesTheSameKeyboardControl() {
        let app = launch()
        XCTAssertTrue(app.goToThoughts())
        XCTAssertTrue(app.chooseFilter("Ideas"))
        let thought = app.buttons.matching(NSPredicate(
            format: "identifier == 'row.open' AND label CONTAINS 'podcast where nobody'"
        )).firstMatch
        XCTAssertTrue(thought.waitForExistence(timeout: 5))
        thought.tap()
        reveal(app.buttons["detail.action.enhance"], app: app)
        app.buttons["detail.action.enhance"].tap()
        let answer = app.textFields["sharpen.answer"]
        XCTAssertTrue(answer.waitForExistence(timeout: 15))
        answer.tap()
        answer.typeText("People interested in new perspectives")
        dismissKeyboard("sharpen.dismissKeyboard", app: app)
        XCTAssertEqual(answer.value as? String, "People interested in new perspectives")
        screenshot("Sharpen keyboard dismissal", app: app)
    }

    func testReviewUsesTheSameKeyboardControl() {
        let app = launch()
        XCTAssertTrue(app.goToReview())
        let answer = app.textFields["review.answer"]
        for _ in 0 ..< 7 {
            if answer.waitForExistence(timeout: 2) {
                break
            }
            let keep = app.buttons["review.act"]
            reveal(keep, app: app)
            keep.tap()
        }
        reveal(answer, app: app)
        answer.tap()
        answer.typeText("Start with a small experiment")
        dismissKeyboard("review.dismissKeyboard", app: app)
        XCTAssertEqual(answer.value as? String, "Start with a small experiment")
        screenshot("Review keyboard dismissal", app: app)
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-store", "--seed-demo"]
        app.launch()
        XCTAssertTrue(app.textFields["capture.field"].waitForExistence(timeout: 10))
        return app
    }

    private func dismissKeyboard(_ identifier: String, app: XCUIApplication) {
        let button = app.buttons[identifier]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        XCTAssertEqual(button.label, "Hide keyboard")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = identifier
        shot.lifetime = .keepAlways
        add(shot)
        button.tap()
        XCTAssertTrue(app.keyboards.element.waitForNonExistence(timeout: 5))
    }

    private func reveal(_ element: XCUIElement, app: XCUIApplication) {
        for _ in 0 ..< 12 {
            if element.exists, element.isHittable {
                return
            }
            app.swipeUp()
        }
        XCTAssertTrue(element.exists)
        XCTAssertTrue(element.isHittable)
    }

    private func screenshot(_ name: String, app: XCUIApplication) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
