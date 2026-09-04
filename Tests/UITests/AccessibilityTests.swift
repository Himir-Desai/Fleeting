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
        field.tap()
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

        // Whichever thought the list leads with. At this type size barely one row fits and a lazy
        // list does not build the ones below it, so naming a specific thought would tie the test
        // to the demo data's ordering — which is exactly what broke it last time.
        let firstRow = app.descendants(matching: .any)["row.open"].firstMatch
        XCTAssertTrue(
            firstRow.waitForExistence(timeout: 15),
            "rows must still render their text at the largest type size"
        )
        XCTAssertFalse(
            firstRow.label.isEmpty,
            "a row that renders no words is a row that says nothing"
        )
        XCTAssertTrue(
            app.tabButton("Home").isHittable,
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
        for tab in ["Home", "Thoughts", "Settings"] {
            XCTAssertTrue(app.tabButton(tab).exists, "the \(tab) tab must be named")
        }

        // Kind is a toolbar menu now rather than a row of chips (ADR-0036), so what has to be
        // named is the control that opens it. A menu reports as more than one element, so this
        // takes the first rather than asserting a single match.
        app.goToThoughts()
        let filter = app.descendants(matching: .any)["inbox.filterMenu"].firstMatch
        XCTAssertTrue(
            filter.waitForExistence(timeout: 10),
            "the filter control must be addressable"
        )
        XCTAssertEqual(filter.label, "Filter thoughts")
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
