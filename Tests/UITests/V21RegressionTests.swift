import XCTest

/// Exercises only the requested v2.1 editing, navigation, completion and input regressions.
@MainActor
final class V21RegressionTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testCompletedPlanThoughtCanOnlyBeReopened() {
        let app = launch()
        app.tabButton("Plan").tap()
        let input = app.textFields["plan.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        input.typeText("Finish v2.1 task\n")
        dismissKeyboard(app, identifier: "plan.dismissKeyboard")
        let checkbox = app.buttons["Finish v2.1 task"]
        XCTAssertTrue(checkbox.waitForExistence(timeout: 5))
        checkbox.tap()
        XCTAssertTrue(app.staticTexts["1 of 1 done"].waitForExistence(timeout: 5))
        app.buttons["Edit Finish v2.1 task"].tap()
        let text = app.textFields["detail.text"]
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        XCTAssertFalse(text.isEnabled)
        XCTAssertFalse(app.buttons["detail.save"].isEnabled)
        let restore = app.buttons["detail.action.complete"]
        reveal(restore, app: app)
        XCTAssertEqual(restore.label, "Mark not done")
        XCTAssertTrue(restore.isEnabled)
        XCTAssertEqual(app.buttons["detail.action.archive"].label, "Archive")
        XCTAssertFalse(app.buttons["detail.action.archive"].isEnabled)
        XCTAssertFalse(app.buttons["Mark done"].exists)
        XCTAssertFalse(app.buttons["detail.restore"].exists)
        assertTaskActionsShareOneRow(app, fullyVisible: true)
        snapshot("Completed task actions in one row", app: app)
        restore.tap()
        XCTAssertTrue(checkbox.waitForExistence(timeout: 5))
        XCTAssertEqual(checkbox.value as? String, "Not done")
        app.buttons["Edit Finish v2.1 task"].tap()
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        let complete = app.buttons["detail.action.complete"]
        reveal(complete, app: app)
        XCTAssertEqual(complete.label, "Mark done")
        XCTAssertTrue(complete.isEnabled)
        XCTAssertTrue(app.buttons["detail.action.archive"].isEnabled)
        assertTaskActionsShareOneRow(app, fullyVisible: true)
        snapshot("Active task actions in one row", app: app)
        complete.tap()
        XCTAssertTrue(app.staticTexts["1 of 1 done"].waitForExistence(timeout: 5))
    }

    func testCompletedTaskActionsStayInOneScrollableRowAtLargestText() {
        let app = launch(largestText: true)
        app.tabButton("Plan").tap()
        let input = app.textFields["plan.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        input.typeText("Large task\n")
        dismissKeyboard(app, identifier: "plan.dismissKeyboard")
        app.buttons["Large task"].tap()
        app.buttons["Edit Large task"].tap()
        XCTAssertTrue(app.textFields["detail.text"].waitForExistence(timeout: 5))
        let restore = app.buttons["detail.action.complete"]
        reveal(restore, app: app)
        XCTAssertEqual(restore.label, "Mark not done")
        assertTaskActionsShareOneRow(app, fullyVisible: false)
        snapshot("Large text task actions in one scrollable row", app: app)
        restore.tap()
        XCTAssertTrue(app.buttons["Large task"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["Large task"].value as? String, "Not done")
    }

    func testArchivedThoughtOpensRestrictedEditorAndRestores() {
        let app = launch(demo: true)
        XCTAssertTrue(app.goToThoughts())
        XCTAssertTrue(app.chooseFilter("Archived"))
        let row = app.buttons["row.openArchived"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        let text = app.textFields["detail.text"]
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        XCTAssertFalse(text.isEnabled)
        XCTAssertFalse(app.buttons["detail.list"].isEnabled)
        let restore = app.buttons["detail.action.archive"]
        reveal(restore, app: app)
        XCTAssertEqual(restore.label, "Unarchive")
        XCTAssertTrue(restore.isEnabled)
        XCTAssertFalse(app.buttons["detail.restore"].exists)
        XCTAssertFalse(app.buttons["detail.action.enhance"].isEnabled)
        XCTAssertFalse(app.buttons["detail.action.delete"].isEnabled)
        reveal(restore, app: app)
        restore.tap()
        XCTAssertTrue(text.waitForNonExistence(timeout: 5))
    }

    func testPageSwitchClearsEditorAndFilterButSettingsPreservesFilter() {
        let app = launch(demo: true)
        XCTAssertTrue(app.goToThoughts())
        XCTAssertTrue(app.chooseFilter("Ideas"))
        let filter = app.buttons["inbox.filterMenu"]
        XCTAssertEqual(filter.value as? String, "Ideas")
        XCTAssertTrue(app.goToSettings())
        app.buttons["settings.done"].tap()
        XCTAssertTrue(filter.waitForExistence(timeout: 5))
        XCTAssertEqual(filter.value as? String, "Ideas")
        app.buttons["row.open"].firstMatch.tap()
        let text = app.textFields["detail.text"]
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        text.tap()
        text.typeText(" v2.1 saved edit")
        dismissKeyboard(app, identifier: "detail.dismissKeyboard")
        app.tabButton("Lists").tap()
        XCTAssertTrue(app.descendants(matching: .any)["lists.emptyDestination"].waitForExistence(timeout: 5))
        XCTAssertFalse(text.exists)
        app.tabButton("Thoughts").tap()
        XCTAssertTrue(filter.waitForExistence(timeout: 5))
        XCTAssertEqual(filter.value as? String, "All")
        XCTAssertFalse(text.exists)
        XCTAssertTrue(app.chooseFilter("Ideas"))
        let edited = app.buttons.matching(NSPredicate(
            format: "identifier == 'row.open' AND label CONTAINS 'v2.1 saved edit'"
        )).firstMatch
        for _ in 0 ..< 6 {
            if edited.exists {
                break
            }
            app.swipeUp()
        }
        XCTAssertTrue(edited.exists, app.debugDescription)
    }

    func testPlanKeyboardDismissalSurvivesTabAndSettingsReentry() {
        let app = launch()
        for _ in 0 ..< 2 {
            app.tabButton("Plan").tap()
            let input = app.textFields["plan.input"]
            XCTAssertTrue(input.waitForExistence(timeout: 5))
            input.tap()
            input.typeText("Draft")
            dismissKeyboard(app, identifier: "plan.dismissKeyboard")
            XCTAssertTrue(app.goToSettings())
            app.buttons["settings.done"].tap()
            input.tap()
            dismissKeyboard(app, identifier: "plan.dismissKeyboard")
            app.tabButton("Home").tap()
        }
    }

    func testCaptureListLabelFitsItsNameAndListPageHasShareAction() {
        let app = launch()
        let field = app.textFields["capture.field"]
        field.tap()
        field.typeText("Keep this draft")
        let picker = app.buttons["capture.lists"]
        let shortWidth = picker.frame.width
        picker.tap()
        app.buttons["Create list"].tap()
        let name = app.textFields["lists.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Long projects and experiments")
        app.buttons["lists.save"].tap()
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        XCTAssertEqual(picker.label, "Long projects and experiments")
        XCTAssertGreaterThan(picker.frame.width, shortWidth)
        XCTAssertLessThanOrEqual(picker.frame.width, 181)
        dismissKeyboard(app, identifier: "capture.dismissKeyboard")
        app.tabButton("Lists").tap()
        app.buttons["Long projects and experiments"].tap()
        XCTAssertTrue(app.buttons["inbox.shareSelectedList"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["inbox.editSelectedList"].exists)
    }

    private func launch(demo: Bool = false, largestText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-store"] + (demo ? ["--seed-demo"] : [])
        if largestText {
            app.launchArguments += [
                "-UIPreferredContentSizeCategoryName",
                "UICTContentSizeCategoryAccessibilityXXXL"
            ]
        }
        app.launch()
        XCTAssertTrue(app.textFields["capture.field"].waitForExistence(timeout: 10))
        return app
    }

    private func assertTaskActionsShareOneRow(_ app: XCUIApplication, fullyVisible: Bool) {
        let row = app.scrollViews["detail.actions"]
        let first = app.buttons["detail.action.complete"]
        let actions = ["complete", "enhance", "snooze", "archive", "delete"].map {
            app.buttons["detail.action." + $0]
        }
        for action in actions {
            XCTAssertTrue(action.exists)
            XCTAssertEqual(action.frame.minY, first.frame.minY, accuracy: 2)
            XCTAssertGreaterThanOrEqual(action.frame.width, 44)
            if fullyVisible {
                XCTAssertGreaterThanOrEqual(action.frame.minX, row.frame.minX - 1)
                XCTAssertLessThanOrEqual(action.frame.maxX, row.frame.maxX + 1)
            }
        }
    }

    private func snapshot(_ name: String, app: XCUIApplication) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func dismissKeyboard(_ app: XCUIApplication, identifier: String) {
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5))
        if keyboard.frame.minY < app.windows.firstMatch.frame.maxY {
            let dismiss = app.buttons[identifier]
            XCTAssertTrue(dismiss.waitForExistence(timeout: 5))
            XCTAssertTrue(dismiss.isHittable)
            dismiss.tap()
            XCTAssertTrue(keyboard.waitForNonExistence(timeout: 5))
        } else {
            app.typeText("\n")
        }
    }

    private func reveal(_ element: XCUIElement, app: XCUIApplication) {
        for _ in 0 ..< 5 {
            if element.isHittable {
                return
            }
            app.swipeUp()
        }
    }
}
