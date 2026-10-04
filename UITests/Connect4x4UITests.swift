import XCTest

final class Connect4x4UITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func start(count: Int = 4, fast: Bool = false, solo: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", fast ? "--fast-timers" : "--long-timers"]
        app.launch()
        let countButton = app.buttons["board-count-\(count)"]
        reveal(countButton, in: app)
        countButton.tap()
        if solo {
            reveal(app.buttons["mode-solo"], in: app)
            app.buttons["mode-solo"].tap()
            XCTAssertTrue(app.buttons["mode-solo"].isSelected, "Solo must be selected before starting")
        }
        let start = app.buttons["start-match"]
        reveal(start, in: app)
        start.tap()
        XCTAssertTrue(app.staticTexts["board-0-moves"].waitForExistence(timeout: 5))
        if solo { XCTAssertTrue(app.staticTexts["YOU ARE CORAL"].exists, app.debugDescription) }
        return app
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<6 {
            let start = app.buttons["start-match"]
            let bottom = start.exists && element.identifier != "start-match"
                ? start.frame.minY - 8 : app.frame.maxY - 24
            // A partly covered button can report hittable while its center is
            // under the sticky CTA. Scroll the whole target into view.
            if element.isHittable && (element.identifier == "start-match" || element.frame.maxY < bottom) { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }

    private func screenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testOneThroughFourBoardsAndFocus() {
        for count in 1...4 {
            let app = start(count: count)
            for index in 0..<count { XCTAssertTrue(app.staticTexts["board-\(index)-moves"].exists) }
            XCTAssertFalse(app.staticTexts["board-\(count)-moves"].exists)
            app.buttons["focus-board-0"].tap()
            XCTAssertTrue(app.buttons["close-focus"].waitForExistence(timeout: 3))
            app.buttons["focused-0-column-3"].tap()
            XCTAssertEqual(app.staticTexts["focused-0-moves"].label, "1 pieces played")
            app.buttons["close-focus"].tap()
            app.terminate()
        }
    }

    func testFourBoardMatchFromSetupToResultsAndRematch() {
        let app = start()
        screenshot(app, name: "Four boards — start")
        for column in [0, 6, 1, 6, 2, 5, 3] {
            for board in 0..<4 { app.buttons["board-\(board)-column-\(column)"].tap() }
        }
        let result = app.staticTexts["match-result"]
        reveal(result, in: app)
        XCTAssertTrue(result.label.contains("Coral takes"))
        for board in 0..<4 { XCTAssertEqual(app.staticTexts["board-\(board)-moves"].label, "7 pieces played") }
        screenshot(app, name: "Completed four-board match")
        reveal(app.buttons["rematch"], in: app)
        app.buttons["rematch"].tap()
        XCTAssertEqual(app.staticTexts["board-0-moves"].label, "0 pieces played")
    }

    func testTimerExpiryMakesLegalMovesWithoutInput() {
        let app = start(fast: true)
        let first = app.staticTexts["board-0-moves"]
        let moved = NSPredicate(format: "label != '0 pieces played'")
        expectation(for: moved, evaluatedWith: first)
        waitForExpectations(timeout: 8)
        for board in 0..<4 { XCTAssertNotEqual(app.staticTexts["board-\(board)-moves"].label, "0 pieces played") }
        screenshot(app, name: "Autopilot after timeout")
    }

    func testLandscapeKeepsAllBoardsVisibleAndFocusPlayable() {
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = start()
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.staticTexts["board-3-moves"].waitForExistence(timeout: 5))
        for board in 0..<4 { XCTAssertTrue(app.staticTexts["board-\(board)-moves"].isHittable) }
        screenshot(app, name: "All four boards in landscape")
        app.buttons["focus-board-0"].tap()
        XCTAssertTrue(app.buttons["focused-0-column-3"].waitForExistence(timeout: 3))
        app.buttons["focused-0-column-3"].tap()
        XCTAssertEqual(app.staticTexts["focused-0-moves"].label, "1 pieces played")
        screenshot(app, name: "Landscape focused controls")
        app.buttons["close-focus"].tap()
    }

    func testSoloComputerRespondsAndOtherBoardStaysIndependent() {
        let app = start(count: 2, solo: true)
        app.buttons["board-0-column-3"].tap()
        screenshot(app, name: "Solo after the first move")
        expectation(for: NSPredicate(format: "label == '2 pieces played'"), evaluatedWith: app.staticTexts["board-0-moves"])
        waitForExpectations(timeout: 5)
        XCTAssertEqual(app.staticTexts["board-1-moves"].label, "0 pieces played")
    }
}
