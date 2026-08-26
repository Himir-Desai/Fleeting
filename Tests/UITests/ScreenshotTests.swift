import XCTest

/// Regenerates the screenshots used in README.md.
///
/// Kept in the suite rather than run by hand so the seeding path and the screens it captures stay
/// working. Attachments are extracted from the result bundle with `xcresulttool`.
@MainActor
final class ScreenshotTests: XCTestCase {
    func testCaptureInboxScreenshot() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-store", "--seed-demo"]
        app.launch()

        _ = app.descendants(matching: .any)["capture.field"].waitForExistence(timeout: 10)
        app.buttons["capture.browse"].tap()
        _ = app.staticTexts["call the dentist back"].waitForExistence(timeout: 10)
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
        app.buttons["capture.browse"].tap()

        let idea = app.staticTexts["newsletter about tools that do one thing"]
        _ = idea.waitForExistence(timeout: 10)
        idea.swipeRight()
        app.buttons["Sharpen"].tap()

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
        app.buttons["capture.browse"].tap()
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
        app.buttons["capture.browse"].tap()
        _ = app.buttons["inbox.settings"].waitForExistence(timeout: 10)
        app.buttons["inbox.settings"].tap()
        _ = app.staticTexts["Sorting"].waitForExistence(timeout: 10)
        Thread.sleep(forTimeInterval: 1)

        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "settings"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
