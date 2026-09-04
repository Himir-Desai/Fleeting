import XCTest

/// Covers Phase 8's first-run explanation: discoverable, dismissible, and never in the way.
final class FirstRunTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testTheExplanationAppearsOnAFirstLaunchAndBlocksNothing() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-store"]
        app.launch()

        let field = app.descendants(matching: .any)["capture.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        XCTAssertEqual(app.alerts.count, 0, "the explanation must never be a modal")
        XCTAssertEqual(app.sheets.count, 0, "the explanation must never be a sheet")
        XCTAssertTrue(
            app.descendants(matching: .any)["capture.hint"].waitForExistence(timeout: 5),
            "a new user should be told what makes this app different"
        )

        // The field is still the thing you land on.
        field.tap()
        field.typeText("still typable")
        XCTAssertTrue(app.buttons["capture.save"].isEnabled)
    }

    func testDismissingTheExplanationSticks() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-store"]
        app.launch()
        _ = app.descendants(matching: .any)["capture.field"].waitForExistence(timeout: 10)

        XCTAssertTrue(app.buttons["capture.hint.dismiss"].waitForExistence(timeout: 5))
        app.buttons["capture.hint.dismiss"].tap()
        XCTAssertFalse(app.descendants(matching: .any)["capture.hint"].exists)

        app.terminate()
        app.launchArguments = []
        app.launch()
        _ = app.descendants(matching: .any)["capture.field"].waitForExistence(timeout: 10)
        XCTAssertFalse(
            app.descendants(matching: .any)["capture.hint"].exists,
            "an explanation that comes back is a nag"
        )
    }

    func testCapturingSomethingRetiresTheExplanation() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-store"]
        app.launch()

        let field = app.descendants(matching: .any)["capture.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["capture.hint"].waitForExistence(timeout: 5))

        field.tap()
        field.typeText("first thought")
        app.buttons["capture.save"].tap()

        XCTAssertFalse(
            app.descendants(matching: .any)["capture.hint"].waitForExistence(timeout: 3),
            "having captured something is proof the explanation was not needed"
        )
    }
}
