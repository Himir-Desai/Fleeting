import XCTest

/// Exercises the weekly checklist, persisted completion and explicit daily review decisions.
@MainActor
final class PlanTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(seeded: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-store"] + (seeded ? ["--seed-plan"] : [])
        app.launch()
        XCTAssertTrue(app.tabButton("Plan").waitForExistence(timeout: 10))
        app.tabButton("Plan").tap()
        XCTAssertTrue(app.descendants(matching: .any)["plan.week"].waitForExistence(timeout: 10))
        return app
    }

    func testAddingAndCompletingTaskSurvivesRelaunch() {
        let app = launch()
        let days = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'plan.day.'"))
        XCTAssertEqual(days.count, 7)
        let input = app.descendants(matching: .any)["plan.input"]
        input.tap()
        input.typeText("Send the checklist")
        app.buttons["plan.add"].tap()
        let task = app.buttons.matching(NSPredicate(format: "label == %@", "Send the checklist")).firstMatch
        XCTAssertTrue(task.waitForExistence(timeout: 5))
        task.tap()
        let completed = expectation(for: NSPredicate(format: "value == 'Done'"), evaluatedWith: task)
        wait(for: [completed], timeout: 5)
        app.terminate()
        app.launchArguments = []
        app.launch()
        app.tabButton("Plan").tap()
        XCTAssertTrue(task.waitForExistence(timeout: 5))
        XCTAssertEqual(task.value as? String, "Done")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Plan completed task"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testEntryBecomesARowAndTheNextInputFollowsIt() {
        let app = launch()
        let input = app.descendants(matching: .any)["plan.input"]
        let addButton = app.buttons["plan.add"]
        XCTAssertLessThanOrEqual(input.frame.height, 50)
        XCTAssertEqual(input.frame.midY, addButton.frame.midY, accuracy: 2)
        input.tap()
        input.typeText("First task")
        addButton.tap()
        let first = app.buttons.matching(NSPredicate(format: "label == 'First task'")).firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(input.frame.minY, first.frame.maxY)
        XCTAssertTrue(app.keyboards.element.exists)
        input.typeText("Second task")
        addButton.tap()
        let second = app.buttons.matching(NSPredicate(format: "label == 'Second task'")).firstMatch
        XCTAssertTrue(second.waitForExistence(timeout: 5))
        XCTAssertLessThan(first.frame.minY, second.frame.minY)
        XCTAssertGreaterThanOrEqual(input.frame.minY, second.frame.maxY)
        app.buttons["plan.dismissKeyboard"].tap()
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Plan flowing task entry"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testReviewKeepsFinishedHistoryAndCarriesUnfinishedTaskToToday() {
        let app = launch(seeded: true)
        let review = app.buttons["plan.review"]
        XCTAssertTrue(review.waitForExistence(timeout: 10))
        review.tap()
        let finishButtons = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH 'plan.review.finish.'"))
        XCTAssertTrue(finishButtons.firstMatch.waitForExistence(timeout: 5))
        finishButtons.firstMatch.tap()
        let carryButtons = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH 'plan.review.carry.'"))
        XCTAssertTrue(carryButtons.firstMatch.waitForExistence(timeout: 5))
        carryButtons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["plan.review.empty"].waitForExistence(timeout: 5))
        let done = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH 'plan.task.' AND value == 'Done'"))
        XCTAssertEqual(done.count, 1)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Daily review finished"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.tabButton("Plan").tap()
        XCTAssertFalse(app.buttons["plan.review"].exists)
        XCTAssertEqual(
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'plan.task.'")).count,
            3
        )
    }

    func testPlanReusesThoughtEditingAndDeletion() {
        let app = launch()
        let input = app.descendants(matching: .any)["plan.input"]
        input.tap()
        input.typeText("Original task")
        app.buttons["plan.add"].tap()
        app.buttons["plan.dismissKeyboard"].tap()
        let open = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'plan.open.'")).firstMatch
        XCTAssertTrue(open.waitForExistence(timeout: 5))
        open.tap()
        let editor = app.descendants(matching: .any)["detail.text"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText(" revised")
        let editedText = (editor.value as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertTrue(editedText.contains("revised"))
        XCTAssertNotEqual(editedText, "Original task")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons[editedText].waitForExistence(timeout: 5))
        app.tabButton("Thoughts").tap()
        let thought = app.buttons["row.open"].firstMatch
        XCTAssertTrue(thought.waitForExistence(timeout: 5))
        thought.tap()
        XCTAssertEqual(
            app.descendants(matching: .any)["detail.text"].value as? String,
            editedText
        )
        app.buttons["detail.action.delete"].tap()
        app.tabButton("Plan").tap()
        XCTAssertFalse(app.buttons[editedText].exists)
    }

    func testCapturedTodoAppearsInPlan() {
        let app = launch()
        app.tabButton("Home").tap()
        let field = app.descendants(matching: .any)["capture.field"]
        field.tap()
        field.typeText("Buy milk for breakfast")
        app.buttons["capture.save"].tap()
        app.tabButton("Thoughts").tap()
        let thought = app.buttons["row.open"].firstMatch
        XCTAssertTrue(thought.waitForExistence(timeout: 5))
        thought.tap()
        let todoType = app.buttons["detail.type.todo"]
        XCTAssertTrue(todoType.waitForExistence(timeout: 5))
        todoType.tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.tabButton("Plan").tap()
        XCTAssertTrue(app.buttons["Buy milk for breakfast"].waitForExistence(timeout: 5))
    }

    func testLargeTextKeepsTheWeekAndTaskEntryAccessible() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--reset-store",
            "--seed-plan",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        app.launch()
        app.tabButton("Plan").tap()
        XCTAssertTrue(app.descendants(matching: .any)["plan.week"].waitForExistence(timeout: 10))
        XCTAssertEqual(
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'plan.day.'")).count,
            7
        )
        app.swipeUp()
        let input = app.descendants(matching: .any)["plan.input"]
        XCTAssertTrue(input.exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Plan accessibility text"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
