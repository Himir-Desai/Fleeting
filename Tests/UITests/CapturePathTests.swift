import XCTest

/// Guards the one invariant that outranks every other consideration in this app:
/// nothing may stand between a cold launch and a focused capture field (ADR-0008).
///
/// These tests are expected to fail the moment anyone adds onboarding, a permission prompt, a
/// rating request, or a "what's new" screen. That failure is the point.
@MainActor
final class CapturePathTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launchWithEmptyStore() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-store"]
        app.launch()
        return app
    }

    func testColdLaunchLandsOnAFocusedCaptureField() {
        let app = launchWithEmptyStore()

        XCTAssertTrue(
            app.descendants(matching: .any)["capture.field"].waitForExistence(timeout: 5),
            "The capture field must exist immediately on a cold launch."
        )
        XCTAssertTrue(
            app.keyboards.element.waitForExistence(timeout: 5),
            "The keyboard must already be up. Capture must cost zero taps."
        )
    }

    func testNothingIsPresentedOverTheCaptureField() {
        let app = launchWithEmptyStore()
        _ = app.descendants(matching: .any)["capture.field"].waitForExistence(timeout: 5)

        XCTAssertEqual(app.alerts.count, 0, "No alert may precede the capture field.")
        XCTAssertEqual(app.sheets.count, 0, "No sheet may precede the capture field.")
    }

    func testTypingAndSavingClearsTheFieldForTheNextThought() {
        let app = launchWithEmptyStore()
        let field = app.descendants(matching: .any)["capture.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))

        field.tap()
        field.typeText("an idea I had at a bad moment")
        app.buttons["capture.save"].tap()

        let saveButton = app.buttons["capture.save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        XCTAssertFalse(
            saveButton.isEnabled,
            "After a successful save the field must be empty and ready for the next thought."
        )
    }
}

/// Covers the rest of Phase 1: what was captured can be found, changed, removed, and survives
/// the app being killed.
@MainActor
final class InboxTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func capture(_ text: String, in app: XCUIApplication) {
        let field = app.descendants(matching: .any)["capture.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(text)
        app.buttons["capture.save"].tap()
    }

    func testAnEmptyInboxSaysSoRatherThanShowingNothing() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-store"]
        app.launch()

        _ = app.descendants(matching: .any)["capture.field"].waitForExistence(timeout: 5)
        app.buttons["capture.browse"].tap()

        XCTAssertTrue(app.staticTexts["inbox.empty"].waitForExistence(timeout: 5))
    }

    func testCapturedThoughtsAppearInTheInboxAndSurviveBeingKilled() {
        let thought = "rank coffee shops by outlet count"

        let app = XCUIApplication()
        app.launchArguments = ["--reset-store"]
        app.launch()
        capture(thought, in: app)

        app.buttons["capture.browse"].tap()
        XCTAssertTrue(
            app.staticTexts[thought].waitForExistence(timeout: 5),
            "A captured thought must appear in the inbox."
        )

        // Force-quit and relaunch *without* the reset flag: the thought must still be there.
        app.terminate()
        app.launchArguments = []
        app.launch()

        _ = app.descendants(matching: .any)["capture.field"].waitForExistence(timeout: 5)
        app.buttons["capture.browse"].tap()

        XCTAssertTrue(
            app.staticTexts[thought].waitForExistence(timeout: 5),
            "Thoughts must survive a force-quit. Losing a capture is unforgivable."
        )
    }

    func testAThoughtCanBeEditedAndDeleted() {
        let original = "somthing about coffee"
        let revised = "rank coffee shops by outlet count"

        let app = XCUIApplication()
        app.launchArguments = ["--reset-store"]
        app.launch()
        capture(original, in: app)

        app.buttons["capture.browse"].tap()
        XCTAssertTrue(app.staticTexts[original].waitForExistence(timeout: 5))

        app.staticTexts[original].tap()
        let editor = app.descendants(matching: .any)["editor.field"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        // Select-all via the long-press menu is unreliable in CI; the keyboard shortcut is not.
        editor.typeKey("a", modifierFlags: .command)
        editor.typeText(revised)
        app.buttons["editor.save"].tap()

        XCTAssertTrue(
            app.staticTexts[revised].waitForExistence(timeout: 5),
            "An edited thought must show its new text."
        )

        app.staticTexts[revised].swipeLeft()
        app.buttons["Delete"].tap()

        XCTAssertTrue(
            app.staticTexts["inbox.empty"].waitForExistence(timeout: 5),
            "Deleting the only thought must leave an empty inbox."
        )
    }
}

/// Covers Phase 2: decay archives rather than deletes, and the archive stays reachable.
@MainActor
final class ArchiveTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(resetting: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = resetting ? ["--reset-store"] : []
        app.launch()
        return app
    }

    private func capture(_ text: String, in app: XCUIApplication) {
        let field = app.descendants(matching: .any)["capture.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(text)
        app.buttons["capture.save"].tap()
    }

    func testTheArchiveIsReachableAndStartsEmpty() {
        let app = launch()
        _ = app.descendants(matching: .any)["capture.field"].waitForExistence(timeout: 5)

        app.buttons["capture.browse"].tap()
        XCTAssertTrue(app.buttons["inbox.archive"].waitForExistence(timeout: 5))
        app.buttons["inbox.archive"].tap()

        XCTAssertTrue(app.staticTexts["archive.empty"].waitForExistence(timeout: 5))
    }

    func testArchivingMovesAThoughtOutOfTheInboxWithoutDestroyingIt() {
        let thought = "an idea whose time has passed"
        let app = launch()
        capture(thought, in: app)

        app.buttons["capture.browse"].tap()
        XCTAssertTrue(app.staticTexts[thought].waitForExistence(timeout: 5))

        app.staticTexts[thought].swipeLeft()
        XCTAssertTrue(app.buttons["Archive"].waitForExistence(timeout: 5))
        app.buttons["Archive"].tap()

        XCTAssertTrue(
            app.staticTexts["inbox.empty"].waitForExistence(timeout: 5),
            "An archived thought must leave the inbox."
        )

        app.buttons["inbox.archive"].tap()
        XCTAssertTrue(
            app.staticTexts[thought].waitForExistence(timeout: 5),
            "Archiving must never destroy the thought."
        )
    }

    func testAnArchivedThoughtCanBeRestoredToTheInbox() {
        let thought = "worth another look"
        let app = launch()
        capture(thought, in: app)

        app.buttons["capture.browse"].tap()
        XCTAssertTrue(app.staticTexts[thought].waitForExistence(timeout: 5))
        app.staticTexts[thought].swipeLeft()
        app.buttons["Archive"].tap()
        XCTAssertTrue(app.staticTexts["inbox.empty"].waitForExistence(timeout: 5))

        app.buttons["inbox.archive"].tap()
        XCTAssertTrue(app.staticTexts[thought].waitForExistence(timeout: 5))
        app.staticTexts[thought].swipeRight()
        XCTAssertTrue(app.buttons["Restore"].waitForExistence(timeout: 5))
        app.buttons["Restore"].tap()

        XCTAssertTrue(app.staticTexts["archive.empty"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(
            app.staticTexts[thought].waitForExistence(timeout: 5),
            "A restored thought must return to the inbox."
        )
    }
}
