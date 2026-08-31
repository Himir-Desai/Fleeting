import XCTest

/// Covers Phase 8's acceptance criterion: the app has to be operable at the largest Dynamic Type
/// size, and every control has to say what it is.
///
/// Type size is set through the launch environment rather than by driving Settings, so the tests
/// stay hermetic.
final class AccessibilityTests: XCTestCase {
    /// The largest accessibility size iOS offers.
    private let largestSize = "UICTContentSizeCategoryAccessibilityXXXL"

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(atLargestType: Bool, arguments: [String] = ["--reset-store"]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        if atLargestType {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", largestSize]
        }
        app.launch()
        return app
    }

    func testCaptureWorksAtTheLargestTypeSize() {
        let app = launch(atLargestType: true)

        let field = app.descendants(matching: .any)["capture.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 10))

        field.typeText("rent split idea")
        let save = app.buttons["capture.save"]
        XCTAssertTrue(save.isHittable, "the save control must stay reachable at 60pt type")
        save.tap()

        app.goToThoughts()
        XCTAssertTrue(
            app.staticTexts["rent split idea"].waitForExistence(timeout: 10),
            "a thought captured at the largest type size must still be stored and listed"
        )
    }

    func testTheInboxIsOperableAtTheLargestTypeSize() {
        let app = launch(atLargestType: true, arguments: ["--reset-store", "--seed-demo"])
        _ = app.descendants(matching: .any)["capture.field"].waitForExistence(timeout: 10)
        app.goToThoughts()

        // The newest thought, so it is the one on screen: at this type size barely one row fits,
        // and a lazy list does not build the ones below it.
        XCTAssertTrue(
            app.staticTexts["ship the decay engine before it decays"].waitForExistence(timeout: 15),
            "rows must still render their text at the largest type size"
        )
        XCTAssertTrue(
            app.tabButton("New thought").isHittable,
            "the way back to capture must survive the largest type size"
        )
        XCTAssertTrue(
            app.tabButton("Settings").isHittable,
            "the tab bar must not collapse into something unreachable"
        )
    }

    func testTheReviewIsOperableAtTheLargestTypeSize() {
        let app = launch(atLargestType: true, arguments: ["--reset-store", "--seed-demo"])
        _ = app.descendants(matching: .any)["capture.field"].waitForExistence(timeout: 10)
        app.goToThoughts()

        guard app.buttons["inbox.review"].waitForExistence(timeout: 15) else {
            XCTFail("the seeded backlog should need decisions")
            return
        }
        app.buttons["inbox.review"].tap()
        _ = app.staticTexts["review.card"].waitForExistence(timeout: 20)

        // All three decisions have to remain reachable; at this type size they stack.
        for identifier in ["review.act", "review.snooze", "review.drop"] {
            XCTAssertTrue(
                app.buttons[identifier].waitForExistence(timeout: 10),
                "\(identifier) must still be on screen at the largest type size"
            )
            XCTAssertTrue(app.buttons[identifier].isHittable, "\(identifier) must be tappable")
        }
    }

    func testEveryControlOnTheCapturePathIsNamed() {
        let app = launch(atLargestType: false)
        _ = app.descendants(matching: .any)["capture.field"].waitForExistence(timeout: 10)

        // Every tab is named, because a glyph on its own is a button VoiceOver calls "button".
        for tab in ["New thought", "Thoughts", "Settings"] {
            XCTAssertTrue(app.tabButton(tab).exists, "the \(tab) tab must be named")
        }

        // The inbox is a tab now, so its old top bar is gone: what has to be named is the
        // filter row that replaced it (ADR-0026).
        app.goToThoughts()
        _ = app.buttons["inbox.filter.all"].waitForExistence(timeout: 10)
        XCTAssertEqual(app.buttons["inbox.filter.all"].label, "All, 0")
        XCTAssertEqual(app.buttons["inbox.filter.archived"].label, "Archived, 0")
        XCTAssertEqual(app.buttons["inbox.filter.idea"].label, "Ideas, 0")
    }

    func testAThoughtRowSaysWhatItIsAndHowMuchLifeItHasLeft() {
        let app = launch(atLargestType: false, arguments: ["--reset-store", "--seed-demo"])
        _ = app.descendants(matching: .any)["capture.field"].waitForExistence(timeout: 10)
        app.goToThoughts()

        // An indicator rather than a control now (ADR-0027), so it is an image — but it still
        // has to say what the thought is, not merely show a glyph.
        let kind = app.images["row.kind"].firstMatch
        XCTAssertTrue(kind.waitForExistence(timeout: 15))
        XCTAssertTrue(
            kind.label.hasPrefix("Kind:"),
            "the kind glyph must say what the thought currently is, not just show a shape"
        )

        // The row combines its children, so one element carries the text, the expiry and the
        // freshness band rather than making VoiceOver stitch three together.
        let row = app.buttons
            .containing(NSPredicate(format: "label BEGINSWITH %@", "pay the parking fine"))
            .firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15), "the seeded todo should be listed")
        XCTAssertTrue(
            row.label.contains("archives"),
            "a row must say when it archives, not only show a meter: \(row.label)"
        )

        // A percentage would be noise. The band is what the fade is trying to say.
        let bands = ["fresh", "settling", "fading", "about to be archived"]
        let spoken = row.value as? String ?? ""
        XCTAssertTrue(bands.contains(spoken), "unexpected spoken freshness: '\(spoken)'")
    }
}
