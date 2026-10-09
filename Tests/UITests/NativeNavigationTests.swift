import XCTest

/// Verifies four permanent native tabs and selection only after a list is chosen.
@MainActor
final class NativeNavigationTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testPermanentNativeTabsAndListSelection() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-store"]
        app.launch()
        XCTAssertTrue(app.textFields["capture.field"].waitForExistence(timeout: 10))
        let bar = app.tabBars.firstMatch
        assertTabs(bar)
        XCTAssertTrue(bar.buttons["Home"].isSelected)
        let choices = app.descendants(matching: .any)["inbox.listChoices"]
        bar.buttons["Lists"].tap()
        XCTAssertTrue(choices.waitForExistence(timeout: 5))
        XCTAssertTrue(bar.buttons["Lists"].isSelected)
        XCTAssertTrue(app.descendants(matching: .any)["lists.emptyDestination"].exists)
        XCTAssertFalse(choices.buttons["All thoughts"].exists)
        XCTAssertFalse(choices.buttons["Plan"].isSelected)
        choices.buttons["Plan"].tap()
        XCTAssertTrue(choices.waitForNonExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["inbox.selectedList"].label, "Plan")
        XCTAssertTrue(bar.buttons["Lists"].isSelected)
        bar.buttons["Lists"].tap()
        XCTAssertTrue(choices.waitForExistence(timeout: 5))
        XCTAssertTrue(choices.buttons["Plan"].isSelected)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.4)).tap()
        XCTAssertTrue(choices.waitForNonExistence(timeout: 5))
        bar.buttons["Thoughts"].tap()
        XCTAssertTrue(bar.buttons["Thoughts"].isSelected)
        XCTAssertEqual(app.staticTexts["inbox.heading"].label, "Thoughts")
        bar.buttons["Lists"].tap()
        XCTAssertTrue(choices.waitForExistence(timeout: 5))
        XCTAssertFalse(choices.buttons["Plan"].isSelected)
        XCTAssertTrue(bar.buttons["Lists"].isSelected)
        assertTabs(bar)
    }

    func testListsLoadFromHomeAfterRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-store"]
        app.launch()
        XCTAssertTrue(app.textFields["capture.field"].waitForExistence(timeout: 10))
        app.tabButton("Lists").tap()
        let choices = app.descendants(matching: .any)["inbox.listChoices"]
        XCTAssertTrue(choices.waitForExistence(timeout: 5))
        choices.buttons["Add List"].tap()
        let name = app.textFields["lists.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Saved projects")
        app.buttons["lists.save"].tap()
        XCTAssertTrue(name.waitForNonExistence(timeout: 5))
        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.textFields["capture.field"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.tabButton("Home").isSelected)
        app.tabButton("Lists").tap()
        XCTAssertTrue(choices.waitForExistence(timeout: 5))
        let saved = choices.buttons["Saved projects"]
        XCTAssertTrue(saved.waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabButton("Lists").isSelected)
        saved.tap()
        XCTAssertTrue(choices.waitForNonExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["inbox.selectedList"].label, "Saved projects")
        XCTAssertTrue(app.tabButton("Lists").isSelected)
    }

    private func assertTabs(_ bar: XCUIElement) {
        XCTAssertEqual(bar.buttons.count, 4)
        for title in ["Home", "Thoughts", "Lists", "Plan"] {
            XCTAssertTrue(bar.buttons[title].exists)
        }
    }

    private func snapshot(_ name: String, app: XCUIApplication) {
        Thread.sleep(forTimeInterval: 0.4)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
