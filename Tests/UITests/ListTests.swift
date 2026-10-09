import XCTest

/// Covers glass list selection, capture drafts, filtering and the built-in Plan destination.
@MainActor
final class ListTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testCreateListWhileCapturingThenFilterAndEditLists() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-store"]
        app.launch()
        let field = app.textFields["capture.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText("A thought for Work")
        let picker = app.buttons["capture.lists"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        XCTAssertEqual(picker.label, "Lists")
        picker.tap()
        app.buttons["Create list"].tap()
        let name = app.textFields["lists.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Work")
        app.buttons["lists.save"].tap()
        XCTAssertTrue(app.buttons["capture.lists"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["capture.lists"].label, "Work")
        XCTAssertEqual(field.value as? String, "A thought for Work")
        field.tap()
        app.buttons["capture.save"].tap()
        let dismiss = app.buttons["capture.dismissKeyboard"]
        if dismiss.exists {
            dismiss.tap()
        }
        XCTAssertTrue(app.goToThoughts())
        XCTAssertTrue(app.buttons["app.settings"].isHittable)
        XCTAssertTrue(app.buttons["inbox.filterMenu"].isHittable)
        XCTAssertTrue(app.tabBars.firstMatch.isHittable)
        app.tabButton("Lists").tap()
        let work = app.buttons.matching(NSPredicate(format: "label == 'Work'")).firstMatch
        XCTAssertTrue(work.waitForExistence(timeout: 5))
        work.tap()
        XCTAssertTrue(app.staticTexts["inbox.selectedList"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["A thought for Work"].exists)
        app.tabButton("Lists").tap()
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Thoughts glass list dropdown"
        shot.lifetime = .keepAlways
        add(shot)
        app.buttons["Edit Lists"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["lists.page"].waitForExistence(timeout: 5))
    }

    func testCaptureIntoPlanSharesTheDatedChecklist() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-store"]
        app.launch()
        let field = app.textFields["capture.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText("Task captured into Plan")
        app.buttons["capture.lists"].tap()
        let plan = app.buttons
            .matching(
                NSPredicate(
                    format: "label == 'Plan' AND identifier != 'checklist'"
                )
            )
            .firstMatch
        XCTAssertTrue(plan.waitForExistence(timeout: 5))
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Capture glass list dropup"
        shot.lifetime = .keepAlways
        add(shot)
        plan.tap()
        app.buttons["capture.save"].tap()
        let dismiss = app.buttons["capture.dismissKeyboard"]
        if dismiss.exists {
            dismiss.tap()
        }
        app.tabButton("Plan").tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label == 'Task captured into Plan'"))
            .firstMatch.waitForExistence(timeout: 5))
    }

    func testOutsideTapClosesCaptureListWithoutDismissingKeyboard() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-store"]
        app.launch()
        let field = app.textFields["capture.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText("Keep this draft")
        app.buttons["capture.lists"].tap()
        let outside = app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: field.frame.midX, dy: field.frame.midY))
        outside.tap()
        XCTAssertTrue(app.keyboards.element.exists)
        XCTAssertTrue(app.buttons["capture.lists"].exists)
        field.typeText(" survives")
        XCTAssertEqual(field.value as? String, "Keep this draft survives")
        app.buttons["capture.lists"].tap()
        app.buttons["Create list"].tap()
        let name = app.textFields["lists.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Unsubmitted list")
        app.buttons["lists.cancel"].tap()
        XCTAssertTrue(name.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 5))
        XCTAssertEqual(field.value as? String, "Keep this draft survives")
    }

    func testOutsideTapOnThoughtsAndLongListLabel() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-store"]
        app.launch()
        XCTAssertTrue(app.goToThoughts())
        XCTAssertEqual(app.tabButton("Lists").label, "Lists")
        app.tabButton("Lists").tap()
        app.buttons["Add List"].tap()
        let name = app.textFields["lists.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Work projects and experiments")
        app.buttons["lists.save"].tap()
        let compact = app.tabButton("Lists")
        XCTAssertTrue(compact.waitForExistence(timeout: 5))
        XCTAssertEqual(compact.label, "Lists")
        XCTAssertEqual(app.staticTexts["inbox.selectedList"].label, "Work projects and experiments")
        XCTAssertLessThanOrEqual(compact.frame.width, 110)
        XCTAssertTrue(app.buttons["inbox.filterMenu"].isHittable)
        XCTAssertTrue(app.buttons["app.settings"].isHittable)
        XCTAssertGreaterThan(compact.frame.minY, app.buttons["inbox.filterMenu"].frame.maxY)
        XCTAssertGreaterThan(compact.frame.midX, app.tabButton("Thoughts").frame.midX)
        compact.tap()
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.6)).tap()
        XCTAssertTrue(compact.isHittable)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Truncated list name beside filter and settings"
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testStackedListCreationMetadataAndDirectEditing() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-store"]
        app.launch()
        XCTAssertTrue(app.goToThoughts())
        app.tabButton("Lists").tap()
        app.buttons["Edit Lists"].tap()
        let manager = app.descendants(matching: .any)["lists.page"]
        XCTAssertTrue(manager.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["lists.done"].exists)
        XCTAssertFalse(manager.buttons["Plan"].exists)
        snapshot("List management bottom sheet", app: app)
        app.buttons["lists.create"].tap()
        let name = app.textFields["lists.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["lists.save"].isEnabled)
        name.tap()
        name.typeText("Work")
        let description = app.textFields["lists.description"]
        description.tap()
        description.typeText("Projects and follow-ups")
        app.buttons["lists.defaultType.todo"].tap()
        XCTAssertTrue(app.buttons["lists.defaultType.todo"].isSelected)
        let hideKeyboard = app.buttons["lists.dismissKeyboard"]
        XCTAssertTrue(hideKeyboard.waitForExistence(timeout: 5))
        hideKeyboard.tap()
        XCTAssertTrue(app.keyboards.element.waitForNonExistence(timeout: 5))
        XCTAssertLessThan(app.buttons["lists.cancel"].frame.midX, app.buttons["lists.save"].frame.midX)
        XCTAssertFalse(app.navigationBars.staticTexts["Create list"].exists)
        snapshot("Stacked list creation form", app: app)
        app.buttons["lists.save"].tap()
        XCTAssertTrue(name.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["lists.done"].isHittable)
        snapshot("One list of lists", app: app)
        let customRow = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'lists.edit.'"))
            .firstMatch
        XCTAssertTrue(customRow.waitForExistence(timeout: 5))
        customRow.tap()
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertEqual(description.value as? String, "Projects and follow-ups")
        name.tap()
        name.typeText(" projects")
        app.buttons["lists.save"].tap()
        XCTAssertTrue(name.waitForNonExistence(timeout: 5))
        app.buttons["lists.done"].tap()
        XCTAssertTrue(manager.waitForNonExistence(timeout: 5))
        let heading = app.staticTexts["inbox.selectedList"]
        XCTAssertTrue(heading.waitForExistence(timeout: 5))
        XCTAssertEqual(heading.label, "Work projects")
        snapshot("Selected list heading and matched toolbar", app: app)
        app.buttons["inbox.editSelectedList"].tap()
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertEqual(name.value as? String, "Work projects")
        snapshot("Direct list editor", app: app)
        app.buttons["lists.cancel"].tap()
        XCTAssertTrue(name.waitForNonExistence(timeout: 5))
        XCTAssertTrue(heading.exists)
        app.tabButton("Home").tap()
        XCTAssertTrue(app.tabButton("Lists").exists)
        app.tabButton("Thoughts").tap()
        XCTAssertTrue(app.tabButton("Lists").waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["inbox.heading"].label, "Thoughts")
    }

    func testLargestTextListCreationAndDeletion() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--reset-store",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        app.launch()
        XCTAssertTrue(app.goToThoughts())
        app.tabButton("Lists").tap()
        app.buttons["Edit Lists"].tap()
        let create = app.buttons["lists.create"]
        XCTAssertTrue(create.waitForExistence(timeout: 5))
        XCTAssertTrue(create.isHittable)
        snapshot("Largest text list management", app: app)
        create.tap()
        let name = app.textFields["lists.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Reading")
        app.buttons["lists.save"].tap()
        XCTAssertTrue(name.waitForNonExistence(timeout: 5))
        app.buttons["lists.done"].tap()
        let edit = app.buttons["inbox.editSelectedList"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        XCTAssertTrue(edit.isHittable)
        edit.tap()
        let delete = app.buttons["lists.delete"]
        for _ in 0 ..< 8 {
            if delete.exists, delete.isHittable {
                break
            }
            app.swipeUp()
        }
        XCTAssertTrue(delete.isHittable)
        snapshot("Largest text list editor", app: app)
        delete.tap()
        XCTAssertTrue(name.waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["inbox.selectedList"].exists)
        XCTAssertTrue(app.tabButton("Lists").isHittable)
    }

    private func snapshot(_ name: String, app: XCUIApplication) {
        Thread.sleep(forTimeInterval: 0.4)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
