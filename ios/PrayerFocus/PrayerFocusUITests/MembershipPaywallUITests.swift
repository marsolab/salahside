import StoreKitTest
import XCTest

final class MembershipPaywallUITests: XCTestCase {
    private var storeKitSession: SKTestSession!
    private var fixtureURL: URL?

    override func setUpWithError() throws {
        continueAfterFailure = false
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "PrayerFocus", withExtension: "storekit"))
        var configuration = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        var groups = try XCTUnwrap(configuration["subscriptionGroups"] as? [[String: Any]])
        // Give each fresh-account UI case its own group so StoreKit's previous
        // process cannot reuse introductory-offer eligibility for this fixture.
        for index in groups.indices {
            let groupID = String(UInt64.random(in: 1_000_000...9_999_999_999))
            groups[index]["id"] = groupID
            var subscriptions = try XCTUnwrap(groups[index]["subscriptions"] as? [[String: Any]])
            for productIndex in subscriptions.indices {
                subscriptions[productIndex]["subscriptionGroupID"] = groupID
            }
            groups[index]["subscriptions"] = subscriptions
        }
        configuration["identifier"] = UUID().uuidString
        configuration["subscriptionGroups"] = groups
        let fixtureURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).storekit")
        self.fixtureURL = fixtureURL
        try JSONSerialization.data(withJSONObject: configuration).write(to: fixtureURL)
        storeKitSession = try SKTestSession(contentsOf: fixtureURL)
        storeKitSession.resetToDefaultState()
        storeKitSession.clearTransactions()
        storeKitSession.disableDialogs = true
        storeKitSession.timeRate = .realTime
    }

    override func tearDownWithError() throws {
        storeKitSession?.clearTransactions()
        if let fixtureURL {
            try FileManager.default.removeItem(at: fixtureURL)
        }
    }

    @MainActor
    private func launchSetup() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-setup"]
        app.launch()
        XCTAssertTrue(app.buttons["setup.continue"].waitForExistence(timeout: 15))
        return app
    }

    @MainActor
    private func completeSetup(_ app: XCUIApplication) {
        app.buttons["setup.city"].tap()
        app.buttons["Dubai"].tap()
        app.buttons["setup.calculationMethod"].tap()
        app.buttons["Muslim World League"].tap()
        app.buttons["setup.continue"].tap()
        XCTAssertTrue(app.buttons["membership.plan.yearly"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testSetupComesBeforePaywallAndPersistsAfterRelaunch() {
        let app = launchSetup()
        XCTAssertFalse(app.buttons["setup.continue"].isEnabled)
        XCTAssertFalse(app.buttons["membership.subscribe"].exists)
        XCTAssertFalse(app.buttons["Start prayer"].exists)
        completeSetup(app)
        app.terminate()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["membership.reviewSetup"].waitForExistence(timeout: 15))
        app.buttons["membership.reviewSetup"].tap()
        XCTAssertTrue(app.buttons["setup.city"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["setup.city"].label.contains("Dubai"))
        XCTAssertTrue(app.buttons["setup.calculationMethod"].label.contains("Muslim World League"))
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["membership.subscribe"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testMatRegistrationIsOptionalAndUnavailableCameraCanBeCancelled() {
        let app = launchSetup()
        let register = app.buttons["mat.register"]
        for _ in 0..<5 where !register.isHittable { app.swipeUp() }
        XCTAssertTrue(register.waitForExistence(timeout: 5))
        register.tap()
        XCTAssertTrue(app.buttons["mat.takePhoto"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["mat.confirmPhoto"].exists)
        app.buttons["mat.takePhoto"].tap()
        XCTAssertTrue(app.staticTexts["mat.message"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["mat.message"].label.contains("camera is unavailable"))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(register.waitForExistence(timeout: 5))
        XCTAssertFalse(app.switches["mat.enabled"].exists)
        for _ in 0..<5 where !app.buttons["setup.city"].isHittable { app.swipeDown() }
        completeSetup(app)
        XCTAssertTrue(app.buttons["membership.subscribe"].exists)
    }

    @MainActor
    func testTrialDisclosureFollowsPlanSelection() {
        let app = launchSetup()
        completeSetup(app)
        XCTAssertTrue(app.buttons["Start 3-day free trial"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["3 days free, then $35.88/year."].exists)
        app.buttons["membership.plan.monthly"].tap()
        XCTAssertTrue(app.staticTexts["3 days free, then $3.99/month."].waitForExistence(timeout: 5))
        capture(app, name: "Three-day trial — monthly")
        app.buttons["membership.plan.yearly"].tap()
        XCTAssertTrue(app.staticTexts["3 days free, then $35.88/year."].waitForExistence(timeout: 5))
        capture(app, name: "Three-day trial — yearly")
    }

    @MainActor
    func testPaywallCannotBeDismissedWithoutSubscription() {
        let app = launchSetup()
        completeSetup(app)
        let subscribe = app.buttons["membership.subscribe"]
        let top = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.14))
        let bottom = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
        top.press(forDuration: 0.1, thenDragTo: bottom)
        XCTAssertTrue(subscribe.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Start prayer"].exists)
        XCTAssertFalse(app.buttons["membership.close"].exists)
    }

    @MainActor
    func testPrivacyCanBeOpenedAndDismissed() {
        let app = launchSetup()
        completeSetup(app)
        let privacy = app.buttons["Privacy"]
        if !privacy.isHittable { app.swipeUp() }
        privacy.tap()
        XCTAssertTrue(app.navigationBars["Privacy"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["membership.subscribe"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testConfirmedTrialOpensToday() {
        let app = launchSetup()
        completeSetup(app)
        XCTAssertTrue(app.buttons["Start 3-day free trial"].waitForExistence(timeout: 10), app.debugDescription)
        app.buttons["membership.subscribe"].tap()
        XCTAssertTrue(app.buttons["Start prayer"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["membership.subscribe"].exists)
        capture(app, name: "SalahSide Today with calculated schedule")
    }

    @MainActor
    func testErasingLocalDataReturnsPaidMemberToSetup() {
        let app = launchSetup()
        completeSetup(app)
        XCTAssertTrue(app.buttons["Start 3-day free trial"].waitForExistence(timeout: 10))
        app.buttons["membership.subscribe"].tap()
        XCTAssertTrue(app.buttons["today.settings"].waitForExistence(timeout: 15))
        app.buttons["today.settings"].tap()
        let erase = app.buttons["Erase local data"]
        for _ in 0..<6 {
            if erase.exists && erase.isHittable && erase.frame.midY < app.frame.maxY - 70 { break }
            app.swipeUp()
        }
        erase.tap()
        app.buttons["Erase settings and check-ins"].tap()
        XCTAssertTrue(app.buttons["setup.continue"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["setup.continue"].isEnabled)
        XCTAssertFalse(app.buttons["Start prayer"].exists)
    }

    @MainActor
    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
