import XCTest

/// Regenerates the screenshots used in README.md.
///
/// Kept in the suite rather than run by hand so the seeding path and the screens it captures stay
/// working. Attachments are extracted from the result bundle with `xcresulttool`.
@MainActor
final class ScreenshotTests: XCTestCase {
    /// Captures the v2.1 list and restore controls using only disposable fixture records.
    func testCaptureV21ListsAndRestoreScreenshots() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--reset-store", "--seed-demo"]
        app.launch()
        let field = app.textFields["capture.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        app.buttons["capture.lists"].tap()
        app.buttons["Create list"].tap()
        let name = app.textFields["lists.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Weekend projects")
        let description = app.textFields["lists.description"]
        description.tap()
        description.typeText("Small ideas worth making time for.")
        app.buttons["lists.save"].tap()
        XCTAssertTrue(name.waitForNonExistence(timeout: 5))

        for body in [
            "a tiny bookshop map for the neighbourhood",
            "a newsletter about places worth walking to"
        ] {
            field.tap()
            field.typeText(body)
            app.buttons["capture.save"].tap()
            let cleared = expectation(for: NSPredicate(format: "value != %@", body), evaluatedWith: field)
            wait(for: [cleared], timeout: 5)
        }
        app.buttons["capture.dismissKeyboard"].tap()
        snapshot("Home selected list", app: app)
        app.tabButton("Lists").tap()
        XCTAssertTrue(app.descendants(matching: .any)["inbox.listChoices"].waitForExistence(timeout: 5))
        snapshot("Lists picker", app: app)
        app.buttons["Weekend projects"].tap()
        XCTAssertTrue(app.buttons["inbox.shareSelectedList"].waitForExistence(timeout: 5))
        snapshot("Selected list", app: app)
        app.buttons["inbox.editSelectedList"].tap()
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        snapshot("List editor", app: app)
        app.buttons["lists.cancel"].tap()

        XCTAssertTrue(app.goToThoughts())
        XCTAssertTrue(app.chooseFilter("Archived"))
        app.buttons["row.openArchived"].firstMatch.tap()
        XCTAssertTrue(app.textFields["detail.text"].waitForExistence(timeout: 5))
        reveal(app.buttons["detail.action.archive"], app: app)
        XCTAssertEqual(app.buttons["detail.action.archive"].label, "Unarchive")
        snapshot("Archived thought", app: app)

        app.tabButton("Plan").tap()
        let input = app.textFields["plan.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        input.typeText("Send the weekend plan\n")
        app.buttons["plan.dismissKeyboard"].tap()
        let complete = app.buttons["Send the weekend plan"]
        XCTAssertTrue(complete.waitForExistence(timeout: 5))
        complete.tap()
        app.buttons["Edit Send the weekend plan"].tap()
        XCTAssertTrue(app.textFields["detail.text"].waitForExistence(timeout: 5))
        reveal(app.buttons["detail.action.complete"], app: app)
        XCTAssertEqual(app.buttons["detail.action.complete"].label, "Mark not done")
        snapshot("Completed task", app: app)
    }

    private func snapshot(_ name: String, app: XCUIApplication) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
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

    func testCaptureCaptureScreenshot() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-store"]
        app.launch()

        _ = app.descendants(matching: .any)["capture.field"].waitForExistence(timeout: 10)
        _ = app.descendants(matching: .any)["capture.hint"].waitForExistence(timeout: 5)
        Thread.sleep(forTimeInterval: 1)

        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "capture"
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testCaptureInboxScreenshot() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-store", "--seed-demo"]
        app.launch()

        _ = app.descendants(matching: .any)["capture.field"].waitForExistence(timeout: 10)
        app.goToThoughts()
        _ = app.staticTexts["pay the parking fine"].waitForExistence(timeout: 10)
        Thread.sleep(forTimeInterval: 2)

        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "inbox"
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testCaptureSharpenScreenshot() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-store", "--seed-demo"]
        app.launch()

        _ = app.descendants(matching: .any)["capture.field"].waitForExistence(timeout: 10)
        app.goToThoughts()

        XCTAssertTrue(app.chooseFilter("Ideas"))
        let idea = app.buttons
            .matching(
                NSPredicate(
                    format: "identifier == 'row.open' AND label CONTAINS 'newsletter about tools that do one thing'"
                )
            )
            .firstMatch
        for _ in 0 ..< 6 {
            if idea.exists, idea.isHittable {
                break
            }
            app.swipeUp()
        }
        XCTAssertTrue(idea.waitForExistence(timeout: 5))
        idea.tap()
        app.buttons["detail.action.enhance"].tap()

        _ = app.staticTexts["sharpen.title"].waitForExistence(timeout: 30)
        Thread.sleep(forTimeInterval: 1)

        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "sharpen"
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testCaptureReviewScreenshot() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-store", "--seed-demo"]
        app.launch()

        _ = app.descendants(matching: .any)["capture.field"].waitForExistence(timeout: 10)
        app.goToThoughts()
        _ = app.buttons["inbox.review"].waitForExistence(timeout: 10)
        app.buttons["inbox.review"].tap()
        _ = app.staticTexts["review.card"].waitForExistence(timeout: 15)
        Thread.sleep(forTimeInterval: 1)

        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "review"
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testCaptureSettingsScreenshot() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-store", "--seed-demo"]
        app.launch()

        _ = app.descendants(matching: .any)["capture.field"].waitForExistence(timeout: 10)
        _ = app.goToSettings()
        _ = app.staticTexts["Sorting"].waitForExistence(timeout: 10)
        Thread.sleep(forTimeInterval: 1)

        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "settings"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
