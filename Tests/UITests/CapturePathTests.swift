import XCTest

/// Guards the one invariant that outranks every other consideration in this app:
/// nothing may stand between a cold launch and a focused capture field (ADR-0008).
///
/// This test is expected to fail the moment anyone adds onboarding, a permission prompt, a
/// rating request, or a "what's new" screen. That failure is the point.
@MainActor
final class CapturePathTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testColdLaunchLandsOnAFocusedCaptureField() {
        let app = XCUIApplication()
        app.launch()

        let field = app.descendants(matching: .any)["capture.field"]
        XCTAssertTrue(
            field.waitForExistence(timeout: 5),
            "The capture field must exist immediately on a cold launch."
        )

        XCTAssertTrue(
            app.keyboards.element.waitForExistence(timeout: 5),
            "The keyboard must already be up. Capture must cost zero taps."
        )
    }

    func testNothingIsPresentedOverTheCaptureField() {
        let app = XCUIApplication()
        app.launch()

        _ = app.descendants(matching: .any)["capture.field"].waitForExistence(timeout: 5)

        XCTAssertEqual(app.alerts.count, 0, "No alert may precede the capture field.")
        XCTAssertEqual(app.sheets.count, 0, "No sheet may precede the capture field.")
    }

    func testTypingAndSavingClearsTheFieldForTheNextThought() {
        let app = XCUIApplication()
        app.launch()

        let field = app.descendants(matching: .any)["capture.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("an idea I had at a bad moment")

        app.buttons["capture.save"].tap()

        let saveButton = app.buttons["capture.save"]
        let clearedField = saveButton.waitForExistence(timeout: 5) && !saveButton.isEnabled
        XCTAssertTrue(
            clearedField,
            "After a successful save the field must be empty and ready for the next thought."
        )
    }
}
