import XCTest

/// Moving between the app's three tabs from a UI test.
///
/// The tabs replaced the inbox's old top bar (`inbox.done`, `inbox.settings`) and capture's
/// browse chip, so every test that used to tap one of those taps a tab instead. Centralised
/// here so the next navigation change is one edit rather than thirty.
extension XCUIApplication {
    /// The tab bar's button for a tab, found by the name shown under its glyph.
    /// - Parameter name: The tab's label.
    /// - Returns: The button, which may not exist yet.
    func tabButton(_ name: String) -> XCUIElement {
        let inBar = tabBars.buttons[name]
        return inBar.exists ? inBar : buttons[name]
    }

    /// Taps a tab, getting the keyboard out of the way first.
    ///
    /// Capture keeps the keyboard up, and on this device it covers the tab bar exactly — a tap
    /// aimed at a tab lands on a key instead.
    private func switchToTab(_ name: String) {
        if keyboards.element.exists {
            // The capture bar's own dismiss control. Tapping background does not reliably put the
            // keyboard down at the accessibility sizes, and a tap at a guessed fraction of the
            // screen lands on whatever the layout moved there since (ADR-0043).
            let hide = descendants(matching: .any)["capture.dismissKeyboard"].firstMatch
            if hide.exists {
                hide.tap()
            } else {
                descendants(matching: .any)["capture.background"].firstMatch.tap()
            }
            _ = keyboards.element.waitForNonExistence(timeout: 3)
        }
        tabButton(name).tap()
    }

    /// Switches to the capture tab and waits for its field.
    @discardableResult
    func goToCapture(timeout: TimeInterval = 10) -> Bool {
        switchToTab("Home")
        return descendants(matching: .any)["capture.field"].waitForExistence(timeout: timeout)
    }

    /// Switches to the thoughts tab and waits for its summary line.
    ///
    /// Waits on the masthead rather than the old `inbox.filter.all` chip: kind moved into a
    /// toolbar menu when urgency became the list's axis (ADR-0036), so the chip row no longer
    /// exists to wait on.
    @discardableResult
    func goToThoughts(timeout: TimeInterval = 10) -> Bool {
        switchToTab("Thoughts")
        return descendants(matching: .any)["inbox.summary"].waitForExistence(timeout: timeout)
    }

    /// Switches to the review tab and waits for it to settle on a card or an empty state.
    @discardableResult
    func goToReview(timeout: TimeInterval = 15) -> Bool {
        switchToTab("Review")
        let card = staticTexts["review.card"]
        let empty = descendants(matching: .any)["review.empty"]
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if card.exists || empty.exists {
                return true
            }
            usleep(200_000)
        }
        return false
    }

    /// Chooses a kind filter, or the archive, from the inbox's toolbar menu.
    ///
    /// The chips this replaces were tapped directly; a menu has to be opened first. Centralised
    /// here so the next change to the filter's shape is one edit (ADR-0036).
    /// - Parameter name: The menu item's label: "All", "Ideas", "To-dos", "Habits", "Archived".
    @discardableResult
    func chooseFilter(_ name: String, timeout: TimeInterval = 10) -> Bool {
        let menu = descendants(matching: .any)["inbox.filterMenu"].firstMatch
        guard menu.waitForExistence(timeout: timeout) else { return false }
        menu.tap()

        let item = buttons[name]
        guard item.waitForExistence(timeout: timeout) else { return false }
        item.tap()
        return true
    }

    /// Switches to the settings tab and waits for the first control it offers.
    ///
    /// Waits on the sorting reality line rather than the old `settings.intelligence` element,
    /// which the Settings rewrite removed — leaving this helper returning false forever while
    /// every caller ignored the result.
    @discardableResult
    func goToSettings(timeout: TimeInterval = 10) -> Bool {
        switchToTab("Settings")
        return descendants(matching: .any)["settings.sorting.reality"]
            .waitForExistence(timeout: timeout)
    }
}

/// The two kinds a correction test can flip between, with the raw value the detail's type chip
/// identifier uses and the label the row's glyph reports.
///
/// The UI tests do not link `Core`, so the pair is spelled out here rather than derived.
enum ThoughtKindName: String {
    case idea
    case todo

    /// The label the row's kind glyph reports for this kind.
    var label: String {
        switch self {
        case .idea: "Idea"
        case .todo: "To-do"
        }
    }
}
