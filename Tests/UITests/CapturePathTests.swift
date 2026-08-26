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

/// Guards invariant 5: capture is at most one tap away from any screen reachable from it.
///
/// A gesture that works but cannot be seen does not count as a way back.
@MainActor
final class ReturnToCaptureTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testTheInboxOffersAVisibleControlBackToCapture() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-store"]
        app.launch()

        _ = app.descendants(matching: .any)["capture.field"].waitForExistence(timeout: 5)
        app.buttons["capture.browse"].tap()
        _ = app.staticTexts["inbox.empty"].waitForExistence(timeout: 5)

        let back = app.buttons["inbox.done"]
        XCTAssertTrue(
            back.waitForExistence(timeout: 5),
            "The inbox must show a visible control back to capture."
        )
        XCTAssertTrue(back.isHittable, "That control must be reachable, not merely present.")

        back.tap()

        XCTAssertTrue(
            app.keyboards.element.waitForExistence(timeout: 5),
            "One tap must return to a focused capture field with the keyboard up."
        )
    }

    func testANewThoughtCanBeCapturedImmediatelyAfterVisitingTheInbox() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-store"]
        app.launch()

        let field = app.descendants(matching: .any)["capture.field"]
        _ = field.waitForExistence(timeout: 5)

        app.buttons["capture.browse"].tap()
        _ = app.staticTexts["inbox.empty"].waitForExistence(timeout: 5)
        app.buttons["inbox.done"].tap()

        // The whole point: capturing still works after a round trip through the inbox.
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("a thought I had after browsing")
        app.buttons["capture.save"].tap()

        XCTAssertFalse(
            app.buttons["capture.save"].isEnabled,
            "The field must clear, proving the capture was saved."
        )

        app.buttons["capture.browse"].tap()
        XCTAssertTrue(
            app.staticTexts["a thought I had after browsing"].waitForExistence(timeout: 5),
            "The thought captured after visiting the inbox must be stored."
        )
    }
}

/// Covers Phase 3: thoughts get sorted without being asked about, and a wrong guess is
/// correctable in the list.
@MainActor
final class ClassificationTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launchAndCapture(_ text: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-store"]
        app.launch()

        let field = app.descendants(matching: .any)["capture.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(text)
        app.buttons["capture.save"].tap()
        return app
    }

    /// Asserts the mechanism, not the verdict.
    ///
    /// Which kind is chosen depends on whichever implementation is answering on this device, and
    /// an on-device model's judgement is not the app's to promise. The rules themselves are
    /// pinned in HeuristicIntelligenceTests, where they are deterministic.
    func testACapturedThoughtIsSortedWithoutBeingAskedAboutIt() {
        let app = launchAndCapture("call the dentist back")

        app.buttons["capture.browse"].tap()
        let kind = app.buttons["row.kind"]
        XCTAssertTrue(kind.waitForExistence(timeout: 5))

        let sorted = NSPredicate(format: "label != %@", "Kind: Unsorted")
        expectation(for: sorted, evaluatedWith: kind)
        waitForExpectations(timeout: 20)
    }

    func testCaptureAsksNothingAboutKind() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-store"]
        app.launch()
        _ = app.descendants(matching: .any)["capture.field"].waitForExistence(timeout: 5)

        // The capture screen must offer no classification control of any sort.
        XCTAssertFalse(app.buttons["row.kind"].exists)
        XCTAssertEqual(app.sheets.count, 0)
    }

    func testAKindCanBeCorrectedFromTheListAndIsRemembered() {
        let app = launchAndCapture("call mum every sunday")

        app.buttons["capture.browse"].tap()
        let kind = app.buttons["row.kind"]
        XCTAssertTrue(kind.waitForExistence(timeout: 5))

        // Correct it to whichever kind it is not, so the test does not depend on the verdict.
        let target = kind.label == "Kind: Idea" ? "Todo" : "Idea"
        kind.tap()
        XCTAssertTrue(app.buttons[target].waitForExistence(timeout: 5))
        app.buttons[target].tap()

        XCTAssertTrue(app.buttons["row.kind"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["row.kind"].label, "Kind: \(target)", "the correction must apply")

        // Leave and come back: a human decision must outlive the screen that made it.
        app.buttons["inbox.done"].tap()
        app.buttons["capture.browse"].tap()
        XCTAssertTrue(app.buttons["row.kind"].waitForExistence(timeout: 5))
        XCTAssertEqual(
            app.buttons["row.kind"].label, "Kind: \(target)",
            "a corrected kind must be remembered, and never overwritten by the classifier"
        )
    }

    func testSettingsSaysHonestlyWhatIsSortingThoughts() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-store"]
        app.launch()
        _ = app.descendants(matching: .any)["capture.field"].waitForExistence(timeout: 5)

        app.buttons["capture.browse"].tap()
        XCTAssertTrue(app.buttons["inbox.settings"].waitForExistence(timeout: 5))
        app.buttons["inbox.settings"].tap()

        XCTAssertTrue(
            app.otherElements["settings.intelligence"].waitForExistence(timeout: 5)
                || app.staticTexts["On-device model"].exists
                || app.staticTexts["Rules"].exists,
            "Settings must state which implementation is answering."
        )
    }
}

/// Covers Phase 4: an idea can be interviewed and written up, and an interrupted interview
/// resumes rather than restarting.
///
/// Timeouts are generous because the on-device model genuinely takes seconds. The assertions are
/// about the mechanism, never about what the model says.
@MainActor
final class SharpenTests: XCTestCase {
    private let modelTimeout: TimeInterval = 90

    override func setUp() {
        continueAfterFailure = false
    }

    /// Opens an idea that has *not* been pre-sharpened by the demo seed, so the interview
    /// genuinely starts from nothing.
    private func launchToAnIdea() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-store", "--seed-demo"]
        app.launch()

        _ = app.descendants(matching: .any)["capture.field"].waitForExistence(timeout: 5)
        app.buttons["capture.browse"].tap()

        let idea = app.staticTexts["learn to sail? or a boat-shaped midlife crisis"]
        XCTAssertTrue(idea.waitForExistence(timeout: 10))
        idea.swipeRight()

        let sharpen = app.buttons["Sharpen"]
        XCTAssertTrue(sharpen.waitForExistence(timeout: 5), "an idea must offer Sharpen")
        sharpen.tap()
        return app
    }

    /// Answers whatever question is on screen, returning its text.
    @discardableResult
    private func answerCurrentQuestion(_ app: XCUIApplication, with text: String) -> String {
        let question = app.staticTexts["sharpen.question"]
        XCTAssertTrue(question.waitForExistence(timeout: modelTimeout))
        let asked = question.label

        let field = app.descendants(matching: .any)["sharpen.answer"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText(text)
        app.buttons["sharpen.next"].tap()
        return asked
    }

    func testTheOriginalNoteStaysVisibleThroughout() {
        let app = launchToAnIdea()

        let original = app.staticTexts["sharpen.original"]
        XCTAssertTrue(original.waitForExistence(timeout: 10))
        XCTAssertEqual(
            original.label, "learn to sail? or a boat-shaped midlife crisis",
            "the raw captured text must stay on screen and unaltered"
        )
    }

    func testAnsweringEveryQuestionProducesAWriteUp() {
        let app = launchToAnIdea()

        // The model decides how many questions to ask, so answer until the write-up appears.
        for _ in 0 ..< 4 {
            if app.staticTexts["sharpen.title"].exists {
                break
            }
            guard app.staticTexts["sharpen.question"].waitForExistence(timeout: modelTimeout) else {
                break
            }
            answerCurrentQuestion(app, with: "people who hate bloated software")
        }

        XCTAssertTrue(
            app.staticTexts["sharpen.title"].waitForExistence(timeout: modelTimeout),
            "answering every question must produce a write-up"
        )
        XCTAssertTrue(
            app.staticTexts["sharpen.detail"].exists,
            "the write-up must be a paragraph, not just a title"
        )
        XCTAssertTrue(
            app.buttons["sharpen.escalate"].exists,
            "a finished write-up must offer the way to take it further"
        )
    }

    func testAnInterruptedInterviewResumesRatherThanRestarting() {
        let app = launchToAnIdea()

        let firstQuestion = answerCurrentQuestion(app, with: "people who hate bloated software")

        // Leave the screen entirely, then come back to it.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let idea = app.staticTexts["learn to sail? or a boat-shaped midlife crisis"]
        XCTAssertTrue(idea.waitForExistence(timeout: 10))
        idea.swipeRight()
        app.buttons["Sharpen"].tap()

        let resumed = app.staticTexts["sharpen.question"]
        if resumed.waitForExistence(timeout: modelTimeout) {
            XCTAssertNotEqual(
                resumed.label, firstQuestion,
                "an interrupted interview must resume, not ask the first question again"
            )
        } else {
            XCTAssertTrue(
                app.staticTexts["sharpen.title"].waitForExistence(timeout: modelTimeout),
                "the interview either resumed at a later question or had already finished"
            )
        }
    }
}

/// Covers reverting a sharpened idea back to the note as it was captured.
@MainActor
final class SharpenRevertTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// The demo seed ships this idea already sharpened, so the write-up is on screen at once.
    private func openTheSharpenedIdea(_ app: XCUIApplication) {
        let idea = app.staticTexts["newsletter about tools that do one thing"]
        XCTAssertTrue(idea.waitForExistence(timeout: 10))
        idea.swipeRight()
        XCTAssertTrue(app.buttons["Sharpen"].waitForExistence(timeout: 5))
        app.buttons["Sharpen"].tap()
    }

    func testRevertingReturnsTheNoteToHowItWasCaptured() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-store", "--seed-demo"]
        app.launch()
        _ = app.descendants(matching: .any)["capture.field"].waitForExistence(timeout: 5)
        app.buttons["capture.browse"].tap()

        openTheSharpenedIdea(app)
        XCTAssertTrue(app.staticTexts["sharpen.title"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["sharpen.detail"].exists)

        app.buttons["sharpen.revert"].tap()
        // SwiftUI renders the dialog's button twice, and the screen behind it also has one
        // labelled Revert, so take the first match on the confirmation's own identifier.
        let confirm = app.buttons["sharpen.revert.confirm"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "reverting must be confirmed, not instant")
        confirm.tap()

        // Back in the inbox, with the note itself intact.
        let idea = app.staticTexts["newsletter about tools that do one thing"]
        XCTAssertTrue(
            idea.waitForExistence(timeout: 10),
            "the note must survive the write-up being removed"
        )

        // Reopening starts over rather than showing the old write-up.
        idea.swipeRight()
        app.buttons["Sharpen"].tap()
        XCTAssertFalse(
            app.staticTexts["sharpen.title"].waitForExistence(timeout: 4),
            "a reverted idea must no longer carry its old write-up"
        )
    }

    func testRevertAsksBeforeDestroyingAnything() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-store", "--seed-demo"]
        app.launch()
        _ = app.descendants(matching: .any)["capture.field"].waitForExistence(timeout: 5)
        app.buttons["capture.browse"].tap()

        openTheSharpenedIdea(app)
        XCTAssertTrue(app.staticTexts["sharpen.title"].waitForExistence(timeout: 20))

        app.buttons["sharpen.revert"].tap()

        XCTAssertTrue(
            app.sheets.firstMatch.waitForExistence(timeout: 5),
            "reverting must ask first — it removes work the user did"
        )
        XCTAssertTrue(
            app.staticTexts["sharpen.title"].exists,
            "nothing may be removed before the confirmation is accepted"
        )
    }
}

/// Covers Phase 5: the review is offered, finite, and never imposed.
@MainActor
final class ReviewTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launchSeeded() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-store", "--seed-demo"]
        app.launch()
        return app
    }

    func testAReviewIsNeverImposedOnLaunchEvenWithABacklog() {
        let app = launchSeeded()

        XCTAssertTrue(
            app.descendants(matching: .any)["capture.field"].waitForExistence(timeout: 5),
            "a backlog needing decisions must still not delay capture"
        )
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 5))
        XCTAssertEqual(app.sheets.count, 0)
        XCTAssertFalse(app.staticTexts["review.card"].exists)
    }

    func testTheInboxInvitesAReviewWhenSomethingNeedsADecision() {
        let app = launchSeeded()
        _ = app.descendants(matching: .any)["capture.field"].waitForExistence(timeout: 5)
        app.buttons["capture.browse"].tap()

        let invitation = app.buttons["inbox.review"]
        XCTAssertTrue(
            invitation.waitForExistence(timeout: 10),
            "the seeded backlog contains fading thoughts, so a review must be offered"
        )
        XCTAssertTrue(invitation.label.contains("need a decision"))
    }

    func testASessionRunsToAnEndAndReportsWhatWasDecided() {
        let app = launchSeeded()
        _ = app.descendants(matching: .any)["capture.field"].waitForExistence(timeout: 5)
        app.buttons["capture.browse"].tap()

        XCTAssertTrue(app.buttons["inbox.review"].waitForExistence(timeout: 10))
        app.buttons["inbox.review"].tap()

        XCTAssertTrue(app.staticTexts["review.card"].waitForExistence(timeout: 10))
        let total = app.staticTexts["review.progress"].label

        // Decide every card. The stack is capped, so this always terminates.
        for _ in 0 ..< 8 {
            guard app.staticTexts["review.card"].exists else { break }
            if app.buttons["review.act"].exists {
                app.buttons["review.act"].tap()
            }
        }

        XCTAssertTrue(
            app.staticTexts["review.summary"].waitForExistence(timeout: 15),
            "a session must end and say what was decided, not run forever (\(total))"
        )
        XCTAssertTrue(app.staticTexts["review.summary"].label.contains("kept"))

        app.buttons["review.finish"].tap()
        XCTAssertTrue(
            app.buttons["inbox.done"].waitForExistence(timeout: 10),
            "finishing a review must return to the app, not strand the user"
        )
    }

    func testLettingGoArchivesRatherThanDestroys() {
        let app = launchSeeded()
        _ = app.descendants(matching: .any)["capture.field"].waitForExistence(timeout: 5)
        app.buttons["capture.browse"].tap()
        XCTAssertTrue(app.buttons["inbox.review"].waitForExistence(timeout: 10))
        app.buttons["inbox.review"].tap()

        XCTAssertTrue(app.staticTexts["review.card"].waitForExistence(timeout: 10))
        let dropped = app.staticTexts["review.card"].label
        app.buttons["review.drop"].tap()

        // Finish the rest of the session, then look for it in the archive.
        for _ in 0 ..< 8 {
            guard app.staticTexts["review.card"].exists else { break }
            app.buttons["review.act"].tap()
        }
        XCTAssertTrue(app.staticTexts["review.summary"].waitForExistence(timeout: 15))
        app.buttons["review.finish"].tap()

        XCTAssertTrue(app.buttons["inbox.archive"].waitForExistence(timeout: 10))
        app.buttons["inbox.archive"].tap()
        XCTAssertTrue(
            app.staticTexts[dropped].waitForExistence(timeout: 10),
            "letting go must archive the thought, never destroy it"
        )
    }
}
