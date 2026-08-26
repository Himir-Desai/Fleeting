import XCTest

/// Covers Phase 7: a build that cannot reach iCloud is a whole app, not a broken one.
///
/// This suite runs with entitlements stripped, so the store falls back to device-local. That is
/// exactly the case the phase has to get right, and it is the one CI can actually observe.
final class SyncTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launchAndOpenSettings() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-store"]
        app.launch()
        _ = app.descendants(matching: .any)["capture.field"].waitForExistence(timeout: 5)

        app.buttons["capture.browse"].tap()
        XCTAssertTrue(app.buttons["inbox.settings"].waitForExistence(timeout: 5))
        app.buttons["inbox.settings"].tap()
        return app
    }

    func testSettingsSaysWhetherThoughtsAreSyncing() {
        let app = launchAndOpenSettings()

        // The row is a stack of two labels, so it matches more than once.
        let row = app.descendants(matching: .any)["settings.sync"].firstMatch
        if !row.waitForExistence(timeout: 5) {
            app.swipeUp()
        }
        XCTAssertTrue(
            row.waitForExistence(timeout: 5),
            "Settings must say plainly whether thoughts leave this device"
        )
        XCTAssertFalse(
            row.label.isEmpty,
            "an empty sync row tells the user nothing"
        )
    }

    func testAStoreThatCannotSyncStillCaptures() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-store"]
        app.launch()

        let field = app.descendants(matching: .any)["capture.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.typeText("rent split idea, per room not per head")
        app.buttons["capture.save"].tap()

        app.buttons["capture.browse"].tap()
        XCTAssertTrue(
            app.staticTexts["rent split idea, per room not per head"].waitForExistence(timeout: 5),
            "a thought captured without iCloud must still be stored and listed"
        )
    }

    func testAMigratedStoreKeepsWhatWasAlreadyCaptured() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-store"]
        app.launch()

        let field = app.descendants(matching: .any)["capture.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.typeText("pay the parking fine")
        app.buttons["capture.save"].tap()
        _ = app.buttons["capture.browse"].waitForExistence(timeout: 5)

        // Relaunching against the existing store reopens it through the migration plan.
        app.terminate()
        app.launchArguments = []
        app.launch()
        _ = app.descendants(matching: .any)["capture.field"].waitForExistence(timeout: 5)
        app.buttons["capture.browse"].tap()

        XCTAssertTrue(
            app.staticTexts["pay the parking fine"].waitForExistence(timeout: 10),
            "reopening a store must never lose what was already in it"
        )
    }

    func testNothingAboutSyncingBlocksCapture() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-store"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["capture.field"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 5))
        XCTAssertEqual(
            app.alerts.count, 0,
            "an iCloud sign-in prompt at launch would be the exact thing ADR-0008 forbids"
        )
    }
}
