import XCTest

/// Checks sharing entry points and read-only UI without pretending an unsigned simulator can invite iCloud
/// users.
@MainActor
final class SharingTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testShareEntryPointDegradesGracefullyAndPrivateListSurvivesRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-store"]
        app.launch()
        XCTAssertTrue(app.textFields["capture.field"].waitForExistence(timeout: 10))
        app.tabButton("Lists").tap()
        app.buttons["Add List"].tap()
        let name = app.textFields["lists.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap(); name.typeText("Together")
        app.buttons["lists.save"].tap()
        XCTAssertTrue(name.waitForNonExistence(timeout: 5))
        app.buttons["inbox.editSelectedList"].tap()
        let share = app.buttons["lists.share"]
        reveal(share, app: app)
        XCTAssertEqual(share.label, "Share List")
        snapshot("Private list sharing entry point", app: app)
        share.tap()
        let alert = app.alerts["iCloud Sharing"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(alert.staticTexts.containing(NSPredicate(format: "label CONTAINS 'isn’t available'"))
            .firstMatch.exists)
        alert.buttons["OK"].tap()
        app.buttons["lists.cancel"].tap()
        app.tabButton("Home").tap()
        let capture = app.textFields["capture.field"]
        capture.tap(); capture.typeText("Still captures without iCloud")
        app.buttons["capture.save"].tap()
        XCTAssertTrue(app.staticTexts["Still captures without iCloud"].waitForExistence(timeout: 5))
        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.textFields["capture.field"].waitForExistence(timeout: 10))
        app.tabButton("Lists").tap()
        XCTAssertTrue(app.buttons["Together"].waitForExistence(timeout: 5))
        app.buttons["Together"].tap()
        XCTAssertEqual(app.staticTexts["inbox.selectedList"].label, "Together")
    }

    func testViewOnlyListDisablesEditsAndStillAllowsPersonalHabitProgress() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-store", "--seed-shared-preview"]
        app.launch()
        XCTAssertTrue(app.textFields["capture.field"].waitForExistence(timeout: 10))
        app.tabButton("Lists").tap()
        let shared = app.buttons["Shared reading"]
        XCTAssertTrue(shared.waitForExistence(timeout: 5))
        shared.tap()
        app.buttons["inbox.editSelectedList"].tap()
        let name = app.textFields["lists.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertFalse(name.isEnabled)
        XCTAssertFalse(app.buttons["lists.save"].isEnabled)
        XCTAssertFalse(app.buttons["lists.delete"].exists)
        let manage = app.buttons["lists.share"]
        reveal(manage, app: app)
        XCTAssertEqual(manage.label, "Manage Sharing")
        XCTAssertTrue(manage.isEnabled)
        snapshot("View-only shared list details", app: app)
        app.buttons["lists.cancel"].tap()
        app.buttons["row.open"].firstMatch.tap()
        let text = app.textFields["detail.text"]
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        XCTAssertFalse(text.isEnabled)
        XCTAssertFalse(app.buttons["detail.action.archive"].exists)
        XCTAssertFalse(app.buttons["detail.action.delete"].exists)
        let keep = app.buttons["detail.kindAction"]
        reveal(keep, app: app)
        XCTAssertTrue(keep.isEnabled)
        keep.tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS '1 day'")).firstMatch
            .waitForExistence(timeout: 5))
        snapshot("View-only habit with personal progress", app: app)
    }

    func testPrivateThoughtEditingAndDeletionUseTheUnifiedStore() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-store"]
        app.launch()
        let capture = app.textFields["capture.field"]
        XCTAssertTrue(capture.waitForExistence(timeout: 10))
        capture.tap()
        capture.typeText("Private note")
        app.buttons["capture.save"].tap()
        app.buttons["capture.dismissKeyboard"].tap()
        XCTAssertTrue(app.goToThoughts())
        app.buttons["row.open"].firstMatch.tap()
        let text = app.textFields["detail.text"]
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        XCTAssertTrue(text.isEnabled)
        text.tap()
        text.typeText("Revised: ")
        let edited = text.value as? String
        XCTAssertTrue(edited?.contains("Private note") == true)
        XCTAssertTrue(edited?.contains("Revised: ") == true)
        app.buttons["detail.dismissKeyboard"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let revised = app.buttons
            .matching(NSPredicate(format: "identifier == 'row.open' AND label CONTAINS 'Revised:'"))
            .firstMatch
        XCTAssertTrue(revised.waitForExistence(timeout: 10))
        revised.tap()
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        XCTAssertEqual(text.value as? String, edited)
        let delete = app.buttons["detail.action.delete"]
        reveal(delete, app: app)
        delete.tap()
        XCTAssertTrue(app.descendants(matching: .any)["inbox.empty"].waitForExistence(timeout: 5))
    }

    func testLargestTextSharedDetailsKeepsManagementAndCloseReachable() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--reset-store", "--seed-shared-preview",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        app.launch()
        XCTAssertTrue(app.textFields["capture.field"].waitForExistence(timeout: 10))
        app.tabButton("Lists").tap()
        XCTAssertTrue(app.buttons["Shared reading"].waitForExistence(timeout: 5))
        app.buttons["Shared reading"].tap()
        app.buttons["inbox.editSelectedList"].tap()
        XCTAssertTrue(app.textFields["lists.name"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["lists.name"].isEnabled)
        let manage = app.buttons["lists.share"]
        reveal(manage, app: app)
        XCTAssertTrue(manage.isEnabled)
        XCTAssertTrue(app.buttons["lists.cancel"].isHittable)
        XCTAssertLessThanOrEqual(manage.frame.maxX, app.frame.maxX)
        snapshot("Largest text shared list details", app: app)
        app.buttons["lists.cancel"].tap()
        XCTAssertTrue(app.buttons["inbox.editSelectedList"].waitForExistence(timeout: 5))
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

    private func snapshot(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
