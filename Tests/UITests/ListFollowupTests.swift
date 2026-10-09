import XCTest

/// Lists owns its destination; navigation selection and saved thought assignment stay independent.
@MainActor
final class ListFollowupTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testListsEntersEmptyDestinationAndClearsTicksOnExit() {
        let app = launch()
        let choices = app.descendants(matching: .any)["inbox.listChoices"]
        let empty = app.descendants(matching: .any)["lists.emptyDestination"]
        for origin in ["Home", "Thoughts", "Plan"] {
            app.tabButton(origin).tap()
            app.tabButton("Lists").tap()
            XCTAssertTrue(choices.waitForExistence(timeout: 5))
            XCTAssertTrue(app.tabButton("Lists").isSelected)
            XCTAssertFalse(app.tabButton(origin).isSelected)
            XCTAssertTrue(empty.exists)
            XCTAssertEqual(app.staticTexts["inbox.heading"].label, "Lists")
            XCTAssertFalse(choices.buttons["All thoughts"].exists)
            XCTAssertFalse(choices.buttons["Plan"].isSelected)
            XCTAssertTrue(choices.buttons["Add List"].exists)
            XCTAssertTrue(choices.buttons["Edit Lists"].exists)
            if origin == "Home" {
                snapshot("Empty Lists destination and no selected row", app: app)
            }
            choices.buttons["Plan"].tap()
            XCTAssertTrue(choices.waitForNonExistence(timeout: 5))
            XCTAssertTrue(app.tabButton("Lists").isSelected)
            XCTAssertEqual(app.staticTexts["inbox.selectedList"].label, "Plan")
            XCTAssertFalse(empty.exists)
            app.tabButton("Lists").tap()
            XCTAssertTrue(choices.waitForExistence(timeout: 5))
            XCTAssertTrue(choices.buttons["Plan"].isSelected)
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.4)).tap()
            XCTAssertTrue(choices.waitForNonExistence(timeout: 5))
        }
        app.tabButton("Home").tap()
        app.tabButton("Lists").tap()
        XCTAssertTrue(choices.waitForExistence(timeout: 5))
        XCTAssertFalse(choices.buttons["Plan"].isSelected)
        XCTAssertTrue(empty.exists)
    }

    func testManagerTypographyAndCircularClose() {
        let app = launch()
        app.tabButton("Lists").tap()
        let choices = app.descendants(matching: .any)["inbox.listChoices"]
        XCTAssertTrue(choices.waitForExistence(timeout: 5))
        choices.buttons["Edit Lists"].tap()
        let manager = app.descendants(matching: .any)["lists.page"]
        XCTAssertTrue(manager.waitForExistence(timeout: 5))
        let plan = manager.staticTexts["Plan"]
        XCTAssertTrue(plan.exists)
        XCTAssertGreaterThan(plan.frame.height, 15)
        XCTAssertGreaterThan(plan.frame.minX, manager.frame.minX + 14)
        XCTAssertFalse(manager.buttons["Plan"].exists)
        snapshot("List rows retain spacing with larger inset text", app: app)
        app.buttons["lists.create"].tap()
        let field = app.textFields["lists.name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        let close = app.buttons["lists.cancel"]
        XCTAssertTrue(close.exists)
        XCTAssertEqual(close.frame.width, close.frame.height, accuracy: 3)
        snapshot("Circular list editor close control", app: app)
        close.tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 5))
    }

    func testThoughtUsesSharedMenuAndKeepsSavedMembership() {
        let app = launch(seed: true)
        XCTAssertTrue(app.goToThoughts())
        app.buttons["row.open"].firstMatch.tap()
        let text = app.textFields["detail.text"]
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        let original = text.value as? String
        let selector = app.buttons["detail.list"]
        reveal(selector, app: app)
        selector.tap()
        let choices = app.descendants(matching: .any)["detail.listChoices"]
        XCTAssertTrue(choices.waitForExistence(timeout: 5))
        XCTAssertTrue(choices.buttons["No list"].exists)
        XCTAssertTrue(choices.buttons["Add List"].exists)
        XCTAssertTrue(choices.buttons["Edit Lists"].exists)
        snapshot("Shared thought assignment menu", app: app)
        choices.buttons["Plan"].tap()
        XCTAssertTrue(choices.waitForNonExistence(timeout: 5))
        XCTAssertEqual(selector.label, "Plan")
        selector.tap()
        XCTAssertTrue(choices.waitForExistence(timeout: 5))
        XCTAssertTrue(choices.buttons["Plan"].isSelected)
        choices.buttons["Add List"].tap()
        let name = app.textFields["lists.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Personal")
        app.buttons["lists.save"].tap()
        XCTAssertTrue(name.waitForNonExistence(timeout: 5))
        XCTAssertTrue(text.exists)
        XCTAssertEqual(text.value as? String, original)
        XCTAssertEqual(selector.label, "Personal")
        selector.tap()
        XCTAssertTrue(choices.waitForExistence(timeout: 5))
        XCTAssertTrue(choices.buttons["Personal"].isSelected)
        choices.buttons["Edit Lists"].tap()
        XCTAssertTrue(app.buttons["lists.done"].waitForExistence(timeout: 5))
        app.buttons["lists.done"].tap()
        XCTAssertTrue(selector.waitForExistence(timeout: 5))
        XCTAssertEqual(selector.label, "Personal")
        selector.tap()
        XCTAssertTrue(choices.waitForExistence(timeout: 5))
        choices.buttons["No list"].tap()
        XCTAssertTrue(choices.waitForNonExistence(timeout: 5))
        XCTAssertEqual(selector.label, "No list")
    }

    func testClearingNavigationSelectionKeepsThoughtMembership() {
        let app = launch(seed: true)
        XCTAssertTrue(app.goToThoughts())
        app.buttons["row.open"].firstMatch.tap()
        let field = app.textFields["detail.text"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        let body = field.value as? String ?? ""
        let selector = app.buttons["detail.list"]
        reveal(selector, app: app)
        selector.tap()
        let assignment = app.descendants(matching: .any)["detail.listChoices"]
        XCTAssertTrue(assignment.waitForExistence(timeout: 5))
        assignment.buttons["Plan"].tap()
        XCTAssertTrue(assignment.waitForNonExistence(timeout: 5))
        XCTAssertEqual(selector.label, "Plan")
        app.tabButton("Lists").tap()
        let navigation = app.descendants(matching: .any)["inbox.listChoices"]
        XCTAssertTrue(navigation.waitForExistence(timeout: 5))
        XCTAssertFalse(navigation.buttons["Plan"].isSelected)
        navigation.buttons["Plan"].tap()
        XCTAssertTrue(navigation.waitForNonExistence(timeout: 5))
        app.tabButton("Home").tap()
        app.tabButton("Plan").tap()
        let storedTask = app.buttons.matching(NSPredicate(format: "label == %@", "Edit " + body)).firstMatch
        reveal(storedTask, app: app)
        storedTask.tap()
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertEqual(field.value as? String, body)
        reveal(selector, app: app)
        XCTAssertEqual(selector.label, "Plan")
    }

    private func launch(seed: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-store"] + (seed ? ["--seed-demo"] : [])
        app.launch()
        XCTAssertTrue(app.textFields["capture.field"].waitForExistence(timeout: 10))
        return app
    }

    private func reveal(_ element: XCUIElement, app: XCUIApplication) {
        for _ in 0 ..< 8 {
            if element.exists, element.isHittable {
                return
            }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }

    private func snapshot(_ name: String, app: XCUIApplication) {
        Thread.sleep(forTimeInterval: 0.4)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
