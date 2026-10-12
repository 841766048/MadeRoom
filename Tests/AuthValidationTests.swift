import XCTest
@testable import MadeRoom

final class AuthValidationTests: XCTestCase {
    func testEmailWhitespaceAndInvalidDomains() {
        XCTAssertTrue(AuthValidation.validEmail(" maker+studio@example.com \n"))
        for invalid in ["", "maker", "maker@", "@example.com", "maker@localhost", "maker@-example.com", "maker@exam ple.com"] {
            XCTAssertFalse(AuthValidation.validEmail(invalid), invalid)
        }
    }
    func testRegistrationRequiresMatchingPasswordAndExplicitAgreement() {
        XCTAssertTrue(AuthValidation.canRegister(email: "maker@example.com", password: "craft1234", confirmation: "craft1234", agreed: true))
        XCTAssertFalse(AuthValidation.canRegister(email: "maker@example.com", password: "craft1234", confirmation: "craft1234", agreed: false))
        XCTAssertFalse(AuthValidation.canRegister(email: "maker@example.com", password: "craft1234", confirmation: "craft1235", agreed: true))
    }
    func testRegistrationRejectsWeakOrShortPasswords() {
        for password in ["", "craft12", "12345678", "craftroom"] {
            XCTAssertFalse(AuthValidation.canRegister(email: "maker@example.com", password: password, confirmation: password, agreed: true))
        }
    }
    @MainActor func testLegalDocumentsUseEmbeddedWebViewAndRecoverableError() {
        for privacy in [false, true] {
            let controller = LegalWebViewController(privacy: privacy)
            controller.loadViewIfNeeded()
            XCTAssertEqual(controller.documentURL, privacy ? LegalLinks.privacyURL : LegalLinks.termsURL)
            XCTAssertFalse(controller.webView.configuration.websiteDataStore.isPersistent)
            XCTAssertEqual(controller.navigationItem.leftBarButtonItem?.accessibilityIdentifier, "auth.legal.close")
            XCTAssertEqual(controller.navigationItem.rightBarButtonItem?.accessibilityIdentifier, "auth.legal.reload")
            controller.webView.stopLoading()
            controller.webView(controller.webView, didFailProvisionalNavigation: nil, withError: NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet))
            let error = controller.view.subviews.first { $0.accessibilityIdentifier == "auth.legal.error" }
            XCTAssertEqual(error?.isHidden, false)
            XCTAssertTrue(controller.webView.isHidden)
            controller.webView(controller.webView, didStartProvisionalNavigation: nil)
            XCTAssertEqual(error?.isHidden, true)
            XCTAssertFalse(controller.webView.isHidden)
        }
    }

    func testBridgeRejectsUntrustedFramesAndMalformedMessages() throws {
        let trusted = try XCTUnwrap(WebOrigin(url: URL(string: "https://app.example.com")!))
        let other = try XCTUnwrap(WebOrigin(url: URL(string: "https://app.example.com.evil.test")!))
        let bridge = AppJavaScriptBridge(origins: [trusted], methods: ["echo": { $0 }])
        let message: [String: Any] = ["version": 1, "method": "echo", "params": ["text": "quotes \" and \n 中文"]]
        let reply = try bridge.response(to: message, origin: trusted, currentOrigin: trusted, mainFrame: true)
        XCTAssertEqual(reply["text"] as? String, "quotes \" and \n 中文")
        XCTAssertThrowsError(try bridge.response(to: message, origin: other, currentOrigin: trusted, mainFrame: true))
        XCTAssertThrowsError(try bridge.response(to: message, origin: trusted, currentOrigin: other, mainFrame: true))
        XCTAssertThrowsError(try bridge.response(to: message, origin: trusted, currentOrigin: trusted, mainFrame: false))
        XCTAssertThrowsError(try bridge.response(to: ["version": 1, "method": "missing", "params": [:]], origin: trusted, currentOrigin: trusted, mainFrame: true))
        XCTAssertThrowsError(try bridge.response(to: "not an object", origin: trusted, currentOrigin: trusted, mainFrame: true))
        XCTAssertNil(WebOrigin(url: URL(string: "http://app.example.com")!))
        XCTAssertNotEqual(trusted, WebOrigin(url: URL(string: "https://app.example.com:8443")!))
        XCTAssertFalse(AppJavaScriptBridge().isEnabled)
    }

    func testCircleMembershipChangesRequireServerAcknowledgement() {
        var state = CircleMembershipState()
        XCTAssertFalse(state.begin("weaving"))
        state.receive(["craft"])
        XCTAssertTrue(state.begin("weaving"))
        XCTAssertFalse(state.begin("weaving"))
        XCTAssertFalse(state.joined.contains("weaving"))
        state.complete("weaving", joined: true, succeeded: false)
        XCTAssertFalse(state.joined.contains("weaving"))
        XCTAssertTrue(state.begin("weaving"))
        state.complete("weaving", joined: true, succeeded: true)
        XCTAssertEqual(state.joined, ["craft", "weaving"])
        XCTAssertTrue(state.begin("weaving"))
        state.complete("weaving", joined: false, succeeded: false)
        XCTAssertTrue(state.joined.contains("weaving"))
        XCTAssertTrue(state.begin("weaving"))
        state.complete("weaving", joined: false, succeeded: true)
        XCTAssertEqual(state.joined, ["craft"])
        state = CircleMembershipState()
        XCTAssertTrue(state.joined.isEmpty)
        XCTAssertFalse(state.ready)
    }

}
