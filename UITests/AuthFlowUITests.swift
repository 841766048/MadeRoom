import XCTest

final class AuthFlowUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        addUIInterruptionMonitor(withDescription:"Password save prompt") { alert in
            for title in ["Not Now", "Later", "\u{4EE5}\u{540E}", "\u{7A0D}\u{540E}"] {
                if alert.buttons[title].exists { alert.buttons[title].tap();return true }
            }
            return false
        }
    }
    private func dismissSystemPasswordPrompt() {
        for system in [XCUIApplication(), XCUIApplication(bundleIdentifier: "com.apple.springboard")] {
        for title in ["Not Now", "Later", "\u{4EE5}\u{540E}", "\u{7A0D}\u{540E}"] {
            let button=system.buttons[title]
            if button.exists { button.tap();return }
        }
        }
    }
    private func emulatorJSON(_ address: String, token: String? = nil, body: [String: Any]) throws -> [String: Any] {
        let url = try XCTUnwrap(URL(string: address))
        XCTAssertEqual(url.host, "127.0.0.1")
        var request = URLRequest(url: url); request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization") }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let done = expectation(description: "Local emulator response")
        var result: Data?; var status = 0
        URLSession.shared.dataTask(with: request) { data, response, _ in
            result = data; status = (response as? HTTPURLResponse)?.statusCode ?? 0; done.fulfill()
        }.resume()
        wait(for: [done], timeout: 15)
        XCTAssertEqual(status, 200)
        return try JSONSerialization.jsonObject(with: XCTUnwrap(result)) as? [String: Any] ?? [:]
    }
    func testKeyboardAvoidanceAndOutsideTapDismissal() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--auth-emulator", "--reset-test-state", "--auth-preview", "login", "--auth-english"]
        app.launch()
        let email=app.textFields["auth.email"]
        XCTAssertTrue(email.waitForExistence(timeout:10));email.tap();email.typeText("keyboard@example.com")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout:5))
        let visible=XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in email.frame.maxY < app.keyboards.firstMatch.frame.minY },object:nil)
        XCTAssertEqual(XCTWaiter.wait(for:[visible],timeout:5),.completed)
        XCTAssertEqual(app.buttons.matching(identifier:"auth.keyboardDone").count,1)
        app.staticTexts["Welcome back"].tap()
        let hidden=XCTNSPredicateExpectation(predicate:NSPredicate(format:"exists == false"),object:app.keyboards.firstMatch)
        XCTAssertEqual(XCTWaiter.wait(for:[hidden],timeout:5),.completed)
        XCTAssertEqual(email.value as? String,"keyboard@example.com")
        app.buttons["auth.register"].tap()
        app.buttons["auth.reveal.confirm"].tap()
        let confirmation=app.textFields["auth.confirm"]
        confirmation.tap();confirmation.typeText("craft1234")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout:5))
        let lowerField=XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in confirmation.frame.maxY < app.keyboards.firstMatch.frame.minY },object:nil)
        XCTAssertEqual(XCTWaiter.wait(for:[lowerField],timeout:5),.completed)
        app.buttons["auth.keyboardDone"].tap()
        let doneHidden=XCTNSPredicateExpectation(predicate:NSPredicate(format:"exists == false"),object:app.keyboards.firstMatch)
        XCTAssertEqual(XCTWaiter.wait(for:[doneHidden],timeout:5),.completed)
    }

    func testMainRouteCannotBypassLoginAfterConsent() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--auth-emulator", "--reset-test-state", "--screen", "D01", "--auth-english"]
        app.launch()
        XCTAssertTrue(app.buttons["auth.privacy.accept"].waitForExistence(timeout: 5))
        app.buttons["auth.privacy.accept"].tap()
        XCTAssertTrue(app.buttons["auth.register"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["auth.close"].exists)
        app.buttons["auth.register"].tap()
        app.buttons["auth.back"].tap()
        XCTAssertTrue(app.buttons["auth.register"].waitForExistence(timeout: 3))
        app.terminate()
        app.launchArguments.removeAll { $0 == "--reset-test-state" }
        app.launch()
        XCTAssertTrue(app.buttons["auth.register"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["auth.privacy.accept"].exists)
        XCTAssertFalse(app.buttons["auth.close"].exists)
    }
    func testRegistrationAndRestoredSession() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--auth-emulator", "--reset-test-state", "--screen", "A01", "--auth-preview", "login", "--auth-chinese"]
        app.launch()
        XCTAssertTrue(app.buttons["auth.register"].waitForExistence(timeout: 5))
        app.buttons["auth.register"].tap()
        let submit = app.buttons["auth.submit"]
        XCTAssertFalse(submit.isEnabled)
        let address = "maker-\(UUID().uuidString.prefix(8))@example.com"
        app.textFields["auth.email"].tap(); app.textFields["auth.email"].typeText(address)
        // The iOS 26 simulator presents a broken Automatic Strong Password cover.
        // Enter through the user-facing visibility control, then verify both secure states.
        app.buttons["auth.keyboardDone"].tap()
        app.buttons["auth.reveal.password"].tap()
        app.textFields["auth.password"].tap(); app.textFields["auth.password"].typeText("craft1234")
        app.buttons["auth.keyboardDone"].tap()
        XCTAssertEqual(app.textFields["auth.password"].value as? String, "craft1234")
        app.buttons["auth.reveal.password"].tap()
        XCTAssertTrue(app.secureTextFields["auth.password"].exists)
        app.buttons["auth.reveal.confirm"].tap()
        app.textFields["auth.confirm"].tap(); app.textFields["auth.confirm"].typeText("craft1234")
        app.buttons["auth.keyboardDone"].tap()
        XCTAssertEqual(app.textFields["auth.confirm"].value as? String, "craft1234")
        app.buttons["auth.reveal.confirm"].tap()
        XCTAssertTrue(app.secureTextFields["auth.confirm"].exists)
        app.buttons["auth.agreement"].tap()
        XCTAssertTrue(submit.isEnabled)
        XCTAssertEqual(app.buttons["auth.agreement"].value as? String, "已同意")
        let selectedState = XCTAttachment(screenshot: app.screenshot())
        selectedState.name = "Registration agreement selected"
        selectedState.lifetime = .keepAlways
        add(selectedState)
        app.buttons["auth.agreement"].tap()
        XCTAssertFalse(submit.isEnabled)
        XCTAssertEqual(app.buttons["auth.agreement"].value as? String, "未同意")
        app.buttons["auth.agreement"].tap()
        XCTAssertTrue(submit.isEnabled)
        submit.tap()
        XCTAssertTrue(app.buttons["tab.D01"].waitForExistence(timeout: 10))
        app.terminate()
        app.launchArguments.removeAll { $0 == "--reset-test-state" }
        app.launch()
        XCTAssertTrue(app.buttons["tab.D01"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["auth.submit"].exists)
        let library = app.buttons["Craft Library"]
        if !library.isHittable { app.swipeUp() }
        XCTAssertTrue(library.waitForExistence(timeout: 3))
        library.tap()
        XCTAssertTrue(app.staticTexts["Keep Your Woven Edges Even"].waitForExistence(timeout: 3))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "English craft library"; screenshot.lifetime = .keepAlways; add(screenshot)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["tab.P01"].tap()
        app.buttons["action.P01.P05"].tap()
        app.buttons["action.P05.P08"].tap()
        app.buttons["action.P08.@signOut"].tap()
        XCTAssertTrue(app.buttons["auth.register"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["tab.D01"].exists)
        app.textFields["auth.email"].tap(); app.textFields["auth.email"].typeText(address)
        app.buttons["auth.keyboardDone"].tap()
        app.buttons["auth.reveal.password"].tap()
        app.textFields["auth.password"].tap(); app.textFields["auth.password"].typeText("wrong1234")
        app.buttons["auth.keyboardDone"].tap(); app.buttons["auth.submit"].tap()
        XCTAssertTrue(app.alerts["无法完成请求"].waitForExistence(timeout: 5))
        app.alerts.buttons["好"].tap()
        XCTAssertFalse(app.buttons["tab.D01"].exists)
        app.textFields["auth.password"].tap()
        app.textFields["auth.password"].typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 9) + "craft1234")
        app.buttons["auth.keyboardDone"].tap(); app.buttons["auth.submit"].tap()
        XCTAssertTrue(app.buttons["tab.D01"].waitForExistence(timeout: 10))
        let main = XCTAttachment(screenshot: app.screenshot())
        main.name = "Authenticated home with hosted images"; main.lifetime = .keepAlways; add(main)
        app.buttons["tab.C01"].tap()
        app.buttons["action.C01.C03"].firstMatch.tap()
        app.buttons["action.C03.C04"].tap()
        let ownText = "A live comment from the app " + UUID().uuidString.prefix(6)
        app.textFields["input.comment"].tap(); app.textFields["input.comment"].typeText(ownText)
        app.buttons["comment.send"].tap()
        XCTAssertTrue(app.staticTexts[ownText].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Synced"].firstMatch.waitForExistence(timeout: 15))
        // Another authenticated client writes through the same emulator rules.
        let other = try emulatorJSON("http://127.0.0.1:9098/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-key", body: ["email": "reader-\(UUID().uuidString)@example.com", "password": "reader1234", "returnSecureToken": true])
        let token = try XCTUnwrap(other["idToken"] as? String)
        let uid = try XCTUnwrap(other["localId"] as? String)
        let remoteText = "Another maker joined the discussion " + UUID().uuidString.prefix(6)
        let remoteID = UUID().uuidString
        app.textFields["input.comment"].tap(); app.textFields["input.comment"].typeText("Keep this unsent draft")
        let fields: [String: Any] = ["knowledgeID": ["stringValue": "woven-reading-corner"], "authorUID": ["stringValue": uid], "authorName": ["stringValue": "Another maker"], "text": ["stringValue": remoteText], "parentID": ["nullValue": NSNull()], "replyTo": ["nullValue": NSNull()]]
        _ = try emulatorJSON("http://127.0.0.1:8188/v1/projects/made-room-20261009/databases/(default)/documents:commit", token: token, body: ["writes": [["update": ["name": "projects/made-room-20261009/databases/(default)/documents/knowledge/woven-reading-corner/comments/\(remoteID)", "fields": fields], "updateTransforms": [["fieldPath": "createdAt", "setToServerValue": "REQUEST_TIME"]]]]])
        XCTAssertTrue(app.staticTexts[remoteText].waitForExistence(timeout: 10))
        XCTAssertEqual(app.textFields["input.comment"].value as? String, "Keep this unsent draft")
        app.textFields["input.comment"].typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 22))
        app.swipeDown()
        app.buttons["comments.test.offline"].tap()
        let offlineText = "An offline comment " + UUID().uuidString.prefix(6)
        app.textFields["input.comment"].tap(); app.textFields["input.comment"].typeText(offlineText)
        app.buttons["comment.send"].tap()
        XCTAssertTrue(app.staticTexts["Waiting to sync"].firstMatch.waitForExistence(timeout: 5))
        app.swipeDown()
        app.buttons["comments.test.online"].tap()
        let noPending = NSPredicate(format: "exists == false")
        expectation(for: noPending, evaluatedWith: app.staticTexts["Waiting to sync"].firstMatch)
        waitForExpectations(timeout: 15)
        XCTAssertTrue(app.staticTexts[offlineText].exists)
        let comments = XCTAttachment(screenshot: app.screenshot())
        comments.name = "Realtime synced comments"; comments.lifetime = .keepAlways; add(comments)

    }
    func testPasswordResetValidationAndNavigation() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--auth-emulator", "--reset-test-state", "--screen", "A01", "--auth-preview", "login", "--auth-chinese"]
        app.launch()
        XCTAssertTrue(app.buttons["auth.forgot"].waitForExistence(timeout: 5))
        app.buttons["auth.forgot"].tap()
        app.buttons["auth.submit"].tap()
        XCTAssertTrue(app.alerts["请检查邮箱"].waitForExistence(timeout: 3))
        app.alerts.buttons["好"].tap()
        app.textFields["auth.email"].tap();app.textFields["auth.email"].typeText("maker@example.com")
        app.buttons["auth.keyboardDone"].tap();app.buttons["auth.submit"].tap()
        XCTAssertTrue(app.alerts["请检查邮箱"].waitForExistence(timeout: 5))
        app.alerts.buttons["好"].tap();app.buttons["auth.login"].tap()
        XCTAssertTrue(app.buttons["auth.register"].waitForExistence(timeout: 3))
    }
    func testPrivacyDeclineDoesNotPersistConsent() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--auth-emulator", "--reset-test-state", "--screen", "A01", "--auth-chinese"]
        app.launch()
        XCTAssertTrue(app.buttons["auth.privacy.decline"].waitForExistence(timeout: 5))
        app.buttons["auth.privacy.decline"].tap()
        XCTAssertTrue(app.buttons["auth.register"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["auth.close"].exists)
        app.terminate()
        app.launchArguments.removeAll { $0 == "--reset-test-state" }
        app.launch()
        XCTAssertTrue(app.buttons["auth.privacy.accept"].waitForExistence(timeout: 5))
        app.buttons["auth.privacy.accept"].tap()
        XCTAssertTrue(app.buttons["auth.register"].waitForExistence(timeout: 3))
        app.terminate();app.launch()
        XCTAssertTrue(app.buttons["auth.register"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["auth.privacy.accept"].exists)
    }
    func testReinstallRequiresLoginAndProfileRestoresFromCloud() throws {
        let address = "profile-\(UUID().uuidString.prefix(8))@example.com"
        _ = try emulatorJSON("http://127.0.0.1:9098/identitytoolkit.googleapis.com/v1/accounts:signUp?key=emulator", body: ["email":address,"password":"craft1234","returnSecureToken":true])
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting","--auth-emulator","--reset-test-state","--auth-english"]
        func signIn() {
            XCTAssertTrue(app.buttons["auth.privacy.accept"].waitForExistence(timeout: 5))
            app.buttons["auth.privacy.accept"].tap()
            app.textFields["auth.email"].tap(); app.textFields["auth.email"].typeText(address)
            app.buttons["auth.keyboardDone"].tap()
            app.buttons["auth.reveal.password"].tap()
            app.textFields["auth.password"].tap(); app.textFields["auth.password"].typeText("craft1234")
            app.buttons["auth.keyboardDone"].tap(); app.buttons["auth.submit"].tap()
            XCTAssertTrue(app.buttons["tab.P01"].waitForExistence(timeout: 10))
        }
        app.launch(); signIn()
        app.buttons["tab.P01"].tap()
        let edit = app.buttons["action.P01.P04"]
        if !edit.isHittable { app.swipeUp() }
        edit.tap()
        let name = app.textFields["input.name"]
        for _ in 0..<4 where !name.isHittable { app.swipeUp() }
        name.tap()
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (name.value as? String ?? "").count) + "Cloud Maker" + "\n")
        app.buttons["action.P04.@profile"].tap()
        let synced = app.staticTexts["profile.sync.status"]
        let ready = NSPredicate(format: "label == %@", "Profile synced")
        expectation(for: ready, evaluatedWith: synced)
        waitForExpectations(timeout: 15)
        XCTAssertTrue(app.staticTexts["Cloud Maker"].exists)
        app.terminate()
        app.launchArguments = ["--uitesting","--auth-emulator","--simulate-reinstall","--auth-english"]
        app.launch()
        XCTAssertFalse(app.buttons["tab.P01"].exists)
        signIn()
        app.buttons["tab.P01"].tap()
        XCTAssertTrue(app.staticTexts["Cloud Maker"].waitForExistence(timeout: 10))
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Profile restored after fresh installation and manual login"; shot.lifetime = .keepAlways; add(shot)
    }

    func testSpaceRestoresFromFirebaseAfterFreshInstallation() throws {
        let address = "space-\(UUID().uuidString.prefix(8))@example.com"
        _ = try emulatorJSON("http://127.0.0.1:9098/identitytoolkit.googleapis.com/v1/accounts:signUp?key=emulator", body: ["email":address,"password":"craft1234","returnSecureToken":true])
        let app = XCUIApplication()
        func signIn() {
            XCTAssertTrue(app.buttons["auth.privacy.accept"].waitForExistence(timeout: 6))
            app.buttons["auth.privacy.accept"].tap()
            app.textFields["auth.email"].tap(); app.textFields["auth.email"].typeText(address)
            app.buttons["auth.keyboardDone"].tap(); app.buttons["auth.reveal.password"].tap()
            app.textFields["auth.password"].tap(); app.textFields["auth.password"].typeText("craft1234")
            app.buttons["auth.keyboardDone"].tap(); app.buttons["auth.submit"].tap()
            XCTAssertTrue(app.buttons["tab.S01"].waitForExistence(timeout: 15))
            app.buttons["tab.S01"].tap()
        }
        app.launchArguments = ["--uitesting","--auth-emulator","--reset-test-state","--auth-english"]
        app.launch(); signIn()
        app.buttons["space.create"].tap()
        app.textFields["input.space"].tap(); app.textFields["input.space"].typeText("Cloud Studio\n")
        app.textViews["input.spaceNotes"].tap(); app.textViews["input.spaceNotes"].typeText("A sunny corner for weaving.")
        app.swipeUp()
        let save = app.buttons["action.S03.@saveSpace"]
        for _ in 0..<4 where !save.isHittable { app.swipeUp() }
        save.tap()
        let synced = app.staticTexts["spaces.sync.status"]
        expectation(for: NSPredicate(format: "label == %@", "Spaces synced"), evaluatedWith: synced)
        waitForExpectations(timeout: 20)
        app.terminate()
        app.launchArguments = ["--uitesting","--auth-emulator","--simulate-reinstall","--auth-english"]
        app.launch(); signIn()
        let space = app.buttons["Cloud Studio"]
        for _ in 0..<6 where !space.isHittable { app.swipeUp() }
        XCTAssertTrue(space.waitForExistence(timeout: 15)); space.tap()
        XCTAssertTrue(app.staticTexts["A sunny corner for weaving."].waitForExistence(timeout: 10))
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Space restored from Firebase"; shot.lifetime = .keepAlways; add(shot)
    }

    func testCircleJoinRestoreLeaveAndAccountIsolation() throws {
        let address = "circle-\(UUID().uuidString.prefix(8))@example.com"
        let second = "circle-other-\(UUID().uuidString.prefix(8))@example.com"
        for email in [address, second] {
            _ = try emulatorJSON("http://127.0.0.1:9098/identitytoolkit.googleapis.com/v1/accounts:signUp?key=emulator", body: ["email": email, "password": "craft1234", "returnSecureToken": true])
        }
        let app = XCUIApplication()
        func signIn(_ email: String, reinstall: Bool = false) {
            app.launchArguments = ["--uitesting", "--auth-emulator", "--auth-english", reinstall ? "--simulate-reinstall" : "--reset-test-state"]
            app.launch()
            XCTAssertTrue(app.buttons["auth.privacy.accept"].waitForExistence(timeout: 8))
            app.buttons["auth.privacy.accept"].tap()
            app.textFields["auth.email"].tap(); app.textFields["auth.email"].typeText(email)
            app.buttons["auth.keyboardDone"].tap()
            app.buttons["auth.reveal.password"].tap()
            app.textFields["auth.password"].tap(); app.textFields["auth.password"].typeText("craft1234")
            app.buttons["auth.keyboardDone"].tap(); app.buttons["auth.submit"].tap()
            XCTAssertTrue(app.buttons["tab.C01"].waitForExistence(timeout: 15))
            app.buttons["tab.C01"].tap()
            let circles = app.segmentedControls.buttons["Circles"]
            let visible = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: circles)
            XCTAssertEqual(XCTWaiter.wait(for: [visible], timeout: 35), .completed)
            circles.tap()
            let craft = app.buttons["action.C07.@circle.craft"]
            XCTAssertTrue(craft.waitForExistence(timeout: 5))
            craft.tap()
        }
        func awaitMembership(_ title: String) {
            let button = app.buttons["action.C08.@join"]
            XCTAssertTrue(button.waitForExistence(timeout: 8))
            let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@ AND enabled == true", title), object: button)
            XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 20), .completed)
        }
        signIn(address)
        awaitMembership("Join circle")
        app.buttons["action.C08.@join"].tap()
        awaitMembership("Joined")
        app.terminate()
        signIn(address, reinstall: true)
        awaitMembership("Joined")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Circle membership restored from server"; screenshot.lifetime = .keepAlways; add(screenshot)
        app.buttons["action.C08.@join"].tap()
        XCTAssertTrue(app.buttons["dialog.action.Leave circle"].waitForExistence(timeout: 5))
        app.buttons["dialog.action.Leave circle"].tap()
        awaitMembership("Join circle")
        // Rejoin first account, then confirm the second account has independent membership.
        app.buttons["action.C08.@join"].tap(); awaitMembership("Joined")
        app.terminate()
        signIn(second)
        awaitMembership("Join circle")
    }

    func testEditorialCommentsPublishAndReload() throws {
        let address = "commenter-\(UUID().uuidString.prefix(8))@example.com"
        _ = try emulatorJSON("http://127.0.0.1:9098/identitytoolkit.googleapis.com/v1/accounts:signUp?key=emulator", body: ["email":address,"password":"craft1234","returnSecureToken":true])
        let app = XCUIApplication()
        func ready(_ element: XCUIElement) {
            XCTAssertTrue(element.waitForExistence(timeout:15))
            let wait = XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in self.dismissSystemPasswordPrompt();return element.isHittable },object:element)
            XCTAssertEqual(XCTWaiter.wait(for:[wait],timeout:60),.completed)
        }
        app.launchArguments = ["--uitesting","--auth-emulator","--auth-english","--reset-test-state"]
        app.launch()
        ready(app.buttons["auth.privacy.accept"]);app.buttons["auth.privacy.accept"].tap()
        app.textFields["auth.email"].tap();app.textFields["auth.email"].typeText(address)
        app.buttons["auth.keyboardDone"].tap();app.buttons["auth.reveal.password"].tap()
        app.textFields["auth.password"].tap();app.textFields["auth.password"].typeText("craft1234")
        app.buttons["auth.keyboardDone"].tap();app.buttons["auth.submit"].tap()
        ready(app.buttons["tab.C01"]);app.buttons["tab.C01"].tap()
        let post = app.buttons["community.post.community-basket-reset"]
        XCTAssertTrue(post.waitForExistence(timeout:15))
        for _ in 0..<20 { dismissSystemPasswordPrompt(); if post.isHittable { break };app.swipeUp() }
        ready(post);post.tap()
        app.swipeUp()
        let like = app.buttons["action.C03.@like"]
        ready(like)
        let previousLikes = like.label
        like.tap()
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label != %@", previousLikes), object: like)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 20), .completed)
        ready(app.buttons["action.C03.C04"]);app.buttons["action.C03.C04"].tap()
        let text = "Online editorial comment " + UUID().uuidString.prefix(6)
        ready(app.textFields["input.comment"])
        app.textFields["input.comment"].tap();app.textFields["input.comment"].typeText(text)
        app.buttons["comment.send"].tap()
        XCTAssertTrue(app.staticTexts["Synced"].firstMatch.waitForExistence(timeout:20))
        app.buttons["navigation.back"].tap()
        ready(app.buttons["action.C03.C04"]);app.buttons["action.C03.C04"].tap()
        XCTAssertTrue(app.staticTexts[text].waitForExistence(timeout:15))
        XCTAssertFalse(app.staticTexts["Comments are not available for this editorial example yet."].exists)
        app.buttons["navigation.back"].tap();app.buttons["navigation.back"].tap()
        ready(app.buttons["tab.D01"]);app.buttons["tab.D01"].tap()
        ready(app.buttons["Craft Library"]);app.buttons["Craft Library"].tap()
        XCTAssertTrue(app.staticTexts["Woven wall hanging"].firstMatch.waitForExistence(timeout:20))
        XCTAssertTrue(app.staticTexts["Updated from cloud"].waitForExistence(timeout:10))
    }

    func testProjectLibraryRestoresAfterLocalClearAndReinstall() throws {
        let address = "library-\(UUID().uuidString.prefix(8))@example.com"
        _ = try emulatorJSON("http://127.0.0.1:9098/identitytoolkit.googleapis.com/v1/accounts:signUp?key=emulator", body: ["email":address,"password":"craft1234","returnSecureToken":true])
        let app = XCUIApplication()
        func ready(_ element: XCUIElement) {
            XCTAssertTrue(element.waitForExistence(timeout:15))
            let wait = XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in self.dismissSystemPasswordPrompt();return element.isHittable },object:element)
            XCTAssertEqual(XCTWaiter.wait(for:[wait],timeout:60),.completed)
        }
        func login(_ reinstall: Bool) {
            app.launchArguments = ["--uitesting","--auth-emulator","--auth-english",reinstall ? "--simulate-reinstall" : "--reset-test-state"]
            app.launch()
            ready(app.buttons["auth.privacy.accept"]);app.buttons["auth.privacy.accept"].tap()
            app.textFields["auth.email"].tap();app.textFields["auth.email"].typeText(address)
            app.buttons["auth.keyboardDone"].tap();app.buttons["auth.reveal.password"].tap()
            app.textFields["auth.password"].tap();app.textFields["auth.password"].typeText("craft1234")
            app.buttons["auth.keyboardDone"].tap();app.buttons["auth.submit"].tap()
            ready(app.buttons["tab.M01"])
        }
        login(false)
        app.buttons["tab.M01"].tap()
        ready(app.buttons["Create project"]);app.buttons["Create project"].tap()
        let create=app.buttons["action.M02.@createProject"]
        for _ in 0..<5 { if create.isHittable { break };app.swipeUp() }
        ready(create);create.tap()
        XCTAssertTrue(app.staticTexts["Woven wall hanging"].firstMatch.waitForExistence(timeout:15))
        XCTAssertTrue(app.staticTexts["Account synced"].waitForExistence(timeout:25))
        app.buttons["navigation.back"].tap()
        ready(app.buttons["tab.P01"]);app.buttons["tab.P01"].tap()
        ready(app.buttons["action.P01.P05"]);app.buttons["action.P01.P05"].tap()
        let clear=app.buttons["action.P05.@deleteAccount"]
        for _ in 0..<6 { if clear.isHittable { break };app.swipeUp() }
        ready(clear);clear.tap();app.buttons["dialog.action.Delete"].tap()
        XCTAssertTrue(app.buttons["auth.submit"].waitForExistence(timeout:15))
        app.terminate();login(true)
        app.buttons["tab.M01"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format:"label == %@","Woven wall hanging")).firstMatch.waitForExistence(timeout:25))
        XCTAssertTrue(app.staticTexts["Account synced"].waitForExistence(timeout:25))
    }

    func testOnlinePublicationAndRestore() throws {
        let address = "publisher-\(UUID().uuidString.prefix(8))@example.com"
        _ = try emulatorJSON("http://127.0.0.1:9098/identitytoolkit.googleapis.com/v1/accounts:signUp?key=emulator", body: ["email":address,"password":"craft1234","returnSecureToken":true])
        let app = XCUIApplication()
        func ready(_ element: XCUIElement) {
            XCTAssertTrue(element.waitForExistence(timeout:30))
            let wait = XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in self.dismissSystemPasswordPrompt();return element.isHittable },object:element)
            XCTAssertEqual(XCTWaiter.wait(for:[wait],timeout:60),.completed)
        }
        func login(_ reinstall: Bool) {
            app.launchArguments = ["--uitesting","--auth-emulator","--auth-english",reinstall ? "--simulate-reinstall" : "--reset-test-state"]
            app.launch()
            ready(app.buttons["auth.privacy.accept"]);app.buttons["auth.privacy.accept"].tap()
            app.textFields["auth.email"].tap();app.textFields["auth.email"].typeText(address)
            app.buttons["auth.keyboardDone"].tap();app.buttons["auth.reveal.password"].tap()
            app.textFields["auth.password"].tap();app.textFields["auth.password"].typeText("craft1234")
            app.buttons["auth.keyboardDone"].tap()
            XCTAssertEqual(app.textFields["auth.email"].value as? String,address)
            XCTAssertEqual(app.textFields["auth.password"].value as? String,"craft1234")
            app.buttons["auth.submit"].tap()
            ready(app.buttons["tab.C01"]);app.buttons["tab.C01"].tap()
        }
        login(false)
        ready(app.buttons["action.C01.C02"]);app.buttons["action.C01.C02"].tap()
        app.textFields["input.title"].tap();app.textFields["input.title"].typeText("My online weave\n")
        app.textViews["input.body"].tap();app.textViews["input.body"].typeText("First line\nSecond line")
        app.toolbars.buttons["Done"].tap()
        app.swipeUp()
        ready(app.buttons["action.C02.@publish"]);app.buttons["action.C02.@publish"].tap()
        XCTAssertTrue(app.staticTexts["Your post is saved online and visible only to you."].waitForExistence(timeout:25))
        app.terminate();login(true)
        ready(app.buttons["action.C01.@myPosts"]);app.buttons["action.C01.@myPosts"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format:"label == %@","My online weave")).firstMatch.waitForExistence(timeout:20))
        XCTAssertFalse(app.staticTexts["Publish failed"].exists)
        app.buttons["action.C01.C02"].tap()
        app.textFields["input.title"].tap();app.textFields["input.title"].typeText("My public weave\n")
        app.textViews["input.body"].tap();app.textViews["input.body"].typeText("A public handmade piece")
        app.toolbars.buttons["Done"].tap();app.swipeUp()
        app.buttons["action.C02.@visibility"].tap();app.buttons["dialog.action.Public"].tap()
        app.buttons["action.C02.@publish"].tap()
        XCTAssertTrue(app.staticTexts["Your post is now available in the community."].waitForExistence(timeout:25))
        app.buttons["dialog.action.OK"].tap()
        app.buttons["navigation.back"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format:"label == %@","My public weave")).firstMatch.waitForExistence(timeout:30))
    }

    func testRealSocialCountsFollowRestoreAndAccountIsolation() throws {
        let address = "social-\(UUID().uuidString.prefix(8))@example.com"
        let second = "social-other-\(UUID().uuidString.prefix(8))@example.com"
        var ownerID = ""
        for email in [address, second] {
            let account = try emulatorJSON("http://127.0.0.1:9098/identitytoolkit.googleapis.com/v1/accounts:signUp?key=emulator", body: ["email": email, "password": "craft1234", "returnSecureToken": true])
            if email == address { ownerID = try XCTUnwrap(account["localId"] as? String) }
        }
        let app = XCUIApplication()
        func awaitLabel(_ element: XCUIElement, _ title: String) {
            XCTAssertTrue(element.waitForExistence(timeout: 10))
            let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@ AND enabled == true", title), object: element)
            XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 25), .completed)
        }
        func signIn(_ email: String, reinstall: Bool = false) {
            app.launchArguments = ["--uitesting", "--auth-emulator", "--auth-english", reinstall ? "--simulate-reinstall" : "--reset-test-state"]
            app.launch()
            XCTAssertTrue(app.buttons["auth.privacy.accept"].waitForExistence(timeout: 8))
            app.buttons["auth.privacy.accept"].tap()
            app.textFields["auth.email"].tap(); app.textFields["auth.email"].typeText(email)
            app.buttons["auth.keyboardDone"].tap(); app.buttons["auth.reveal.password"].tap()
            app.textFields["auth.password"].tap(); app.textFields["auth.password"].typeText("craft1234")
            app.buttons["auth.keyboardDone"].tap(); app.buttons["auth.submit"].tap()
            XCTAssertTrue(app.buttons["tab.P01"].waitForExistence(timeout: 15))
            let visible = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: app.buttons["tab.P01"])
            XCTAssertEqual(XCTWaiter.wait(for: [visible], timeout: 35), .completed)
            app.buttons["tab.P01"].tap()
        }
        signIn(address)
        awaitLabel(app.buttons["profile.social.Following"], "0 Following")
        awaitLabel(app.buttons["profile.social.Followers"], "0 Followers")
        app.buttons["profile.social.Followers"].tap()
        XCTAssertTrue(app.staticTexts["No followers yet."].waitForExistence(timeout: 10))
        app.buttons["navigation.back"].tap()
        app.buttons["tab.C01"].tap()
        let feedReady = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: app.segmentedControls.buttons["Following"])
        XCTAssertEqual(XCTWaiter.wait(for: [feedReady], timeout: 40), .completed)
        app.segmentedControls.buttons["Following"].tap()
        XCTAssertTrue(app.staticTexts["Follow a creator to see their posts here."].waitForExistence(timeout: 10))
        app.segmentedControls.buttons["For you"].tap()
        let post = app.buttons["community.post.community-basket-reset"]
        XCTAssertTrue(post.waitForExistence(timeout: 15))
        for _ in 0..<5 { if post.isHittable { break }; app.swipeUp() }
        let postReady = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: post)
        XCTAssertEqual(XCTWaiter.wait(for: [postReady], timeout: 40), .completed)
        post.tap()
        let creator = app.buttons["View creator"]
        for _ in 0..<4 { if creator.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(creator.isHittable); creator.tap()
        awaitLabel(app.buttons["creator.follow.example-nora"], "Follow")
        app.buttons["creator.follow.example-nora"].tap()
        awaitLabel(app.buttons["creator.follow.example-nora"], "Following")
        app.buttons["navigation.back"].tap(); app.buttons["navigation.back"].tap()
        app.buttons["tab.P01"].tap()
        awaitLabel(app.buttons["profile.social.Following"], "1 Following")
        awaitLabel(app.buttons["profile.social.Followers"], "0 Followers")
        // An independently authenticated member follows this account; the live follower count must change.
        let remote = try emulatorJSON("http://127.0.0.1:9098/identitytoolkit.googleapis.com/v1/accounts:signUp?key=emulator", body: ["email": "follower-\(UUID().uuidString)@example.com", "password": "craft1234", "returnSecureToken": true])
        let remoteUID = try XCTUnwrap(remote["localId"] as? String)
        let remoteToken = try XCTUnwrap(remote["idToken"] as? String)
        let prefix = "projects/made-room-20261009/databases/(default)/documents/"
        _ = try emulatorJSON("http://127.0.0.1:8188/v1/projects/made-room-20261009/databases/(default)/documents:commit", token: remoteToken, body: ["writes": [["update": ["name": prefix + "publicProfiles/" + remoteUID, "fields": ["uid": ["stringValue": remoteUID], "displayName": ["stringValue": "Test member"], "biography": ["stringValue": ""], "avatarID": ["stringValue": "studio"], "isExample": ["booleanValue": false]]]]]])
        let source = "socialFollows/" + remoteUID + ":" + ownerID
        let eventID = "follow:" + source.replacingOccurrences(of: "/", with: "~") + ":" + ownerID
        let stamp = [["fieldPath": "createdAt", "setToServerValue": "REQUEST_TIME"]]
        _ = try emulatorJSON("http://127.0.0.1:8188/v1/projects/made-room-20261009/databases/(default)/documents:commit", token: remoteToken, body: ["writes": [
            ["update": ["name": prefix + source, "fields": ["followerUID": ["stringValue": remoteUID], "followingUID": ["stringValue": ownerID]]], "updateTransforms": stamp],
            ["update": ["name": prefix + "users/" + ownerID + "/inbox/" + eventID, "fields": ["actorUID": ["stringValue": remoteUID], "recipientUID": ["stringValue": ownerID], "kind": ["stringValue": "follow"], "sourcePath": ["stringValue": source], "read": ["booleanValue": false]]], "updateTransforms": stamp]
        ]])
        app.buttons["action.P01.P03"].tap()
        XCTAssertTrue(app.buttons["inbox." + eventID].waitForExistence(timeout: 15))
        app.buttons["inbox." + eventID].tap()
        XCTAssertTrue(app.staticTexts["Test member"].firstMatch.waitForExistence(timeout: 15))
        app.buttons["navigation.back"].tap(); app.buttons["navigation.back"].tap()

        awaitLabel(app.buttons["profile.social.Followers"], "1 Followers")
        app.terminate(); signIn(address, reinstall: true)
        awaitLabel(app.buttons["profile.social.Following"], "1 Following")
        awaitLabel(app.buttons["profile.social.Followers"], "1 Followers")
        app.buttons["profile.social.Following"].tap()
        awaitLabel(app.buttons["creator.follow.example-nora"], "Following")
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Real relationship restored from server"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["creator.follow.example-nora"].tap()
        XCTAssertTrue(app.staticTexts["Not following anyone yet."].waitForExistence(timeout: 15))
        app.buttons["navigation.back"].tap()
        app.buttons["tab.P01"].tap(); awaitLabel(app.buttons["profile.social.Following"], "0 Following")
        app.terminate(); signIn(second)
        awaitLabel(app.buttons["profile.social.Following"], "0 Following")
        awaitLabel(app.buttons["profile.social.Followers"], "0 Followers")
    }

}
