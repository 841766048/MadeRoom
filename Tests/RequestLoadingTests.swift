import XCTest
@testable import MadeRoom

@MainActor final class RequestLoadingTests: XCTestCase {
    func testLoadingBlocksUnderlyingControlsUntilLastRequestFinishes() async throws {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let button = UIButton(frame: host.bounds); host.addSubview(button)
        let manager = NetworkLoading(); manager.attach(to: host)
        let first = manager.begin(), second = manager.begin()
        try await Task.sleep(nanoseconds: 320_000_000)
        host.layoutIfNeeded()
        let shield = try XCTUnwrap(host.subviews.first { $0 is RequestLoadingView })
        XCTAssertTrue(shield.isUserInteractionEnabled)
        XCTAssertTrue(shield.accessibilityViewIsModal)
        XCTAssertTrue(host.hitTest(CGPoint(x: 20, y: 20), with: nil) === shield)
        first.finish()
        XCTAssertTrue(host.hitTest(CGPoint(x: 20, y: 20), with: nil) === shield)
        second.finish()
        XCTAssertTrue(host.hitTest(CGPoint(x: 20, y: 20), with: nil) === button)
    }
    func testTimeoutRemovesTouchShield() async throws {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let button = UIButton(frame: host.bounds); host.addSubview(button)
        let manager = NetworkLoading(); manager.attach(to: host)
        let ticket = manager.begin(timeout: 0.4)
        try await Task.sleep(nanoseconds: 300_000_000)
        host.layoutIfNeeded()
        XCTAssertFalse(host.hitTest(CGPoint(x: 20, y: 20), with: nil) === button)
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertTrue(host.hitTest(CGPoint(x: 20, y: 20), with: nil) === button)
        ticket.finish()
    }
    func testConcurrentRequestsFinishIndependently() {
        let manager = NetworkLoading()
        let first = manager.begin(), second = manager.begin()
        XCTAssertEqual(manager.activeCount, 2)
        first.finish(); first.finish()
        XCTAssertEqual(manager.activeCount, 1)
        second.finish()
        XCTAssertEqual(manager.activeCount, 0)
    }
    func testTimeoutEndsOnlyItsOwnVisualWait() async throws {
        let manager = NetworkLoading()
        let slow = manager.begin(timeout: 0.01), other = manager.begin()
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(manager.activeCount, 1)
        slow.finish()
        XCTAssertEqual(manager.activeCount, 1)
        other.finish()
        XCTAssertEqual(manager.activeCount, 0)
    }
    func testReleasedTicketCleansUpRequest() {
        let manager = NetworkLoading()
        var ticket: NetworkLoadingTicket? = manager.begin()
        XCTAssertNotNil(ticket)
        XCTAssertEqual(manager.activeCount, 1)
        ticket = nil
        XCTAssertEqual(manager.activeCount, 0)
    }
    func testFinishedFastRequestNeverShowsOverlay() async throws {
        let host = UIView(), loading = RequestLoadingView()
        loading.show(in: host, delay: 0.02)
        loading.dismiss()
        try await Task.sleep(nanoseconds: 60_000_000)
        XCTAssertFalse(loading.isWaiting)
        XCTAssertTrue(host.subviews.isEmpty)
    }
    func testRepeatedRequestCancelsOldPresentationAndDismisses() async throws {
        let oldHost = UIView(), host = UIView(), loading = RequestLoadingView()
        loading.show(in: oldHost, delay: 0.01)
        loading.show(in: host, delay: 0.02)
        try await Task.sleep(nanoseconds: 60_000_000)
        XCTAssertTrue(oldHost.subviews.isEmpty)
        XCTAssertTrue(loading.superview === host)
        host.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        host.backgroundColor = .white
        host.layoutIfNeeded()
        let preview = UIGraphicsImageRenderer(size: host.bounds.size).image { context in
            host.layer.render(in: context.cgContext)
        }
        let attachment = XCTAttachment(image: preview)
        attachment.name = "Native request loading"
        attachment.lifetime = .keepAlways
        add(attachment)
        loading.dismiss()
        XCTAssertTrue(host.subviews.isEmpty)
    }
}
