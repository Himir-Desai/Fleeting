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
    /// aimed at a tab lands on a key instead. Dismissing first is what makes tab navigation
    /// reliable straight after typing.
    private func switchToTab(_ name: String) {
        if keyboards.element.exists {
            // Capture puts the keyboard away when the background is tapped, and that is the only
            // way down without touch. Never types, so the field's contents are untouched.
            coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55)).tap()
            _ = keyboards.element.waitForNonExistence(timeout: 3)
        }
        tabButton(name).tap()
    }

    /// Switches to the capture tab and waits for its field.
    @discardableResult
    func goToCapture(timeout: TimeInterval = 10) -> Bool {
        switchToTab("New thought")
        return descendants(matching: .any)["capture.field"].waitForExistence(timeout: timeout)
    }

    /// Switches to the thoughts tab and waits for its filter row.
    @discardableResult
    func goToThoughts(timeout: TimeInterval = 10) -> Bool {
        switchToTab("Thoughts")
        return buttons["inbox.filter.all"].waitForExistence(timeout: timeout)
    }

    /// Switches to the settings tab and waits for the first thing it reports.
    @discardableResult
    func goToSettings(timeout: TimeInterval = 10) -> Bool {
        switchToTab("Settings")
        return descendants(matching: .any)["settings.intelligence"].waitForExistence(timeout: timeout)
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
