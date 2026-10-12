import XCTest
@testable import MadeRoom

@MainActor final class LaunchAnimationTests: XCTestCase {
    func testCompletionRunsOnlyOnceAfterInterruption() {
        let controller = LaunchAnimationController()
        controller.loadViewIfNeeded()
        var count = 0
        controller.onFinish = { count += 1 }
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        controller.finish()
        XCTAssertEqual(count, 1)
        XCTAssertTrue(controller.finished)
    }
    func testReducedMotionCompletesAndDoesNotReplay() async throws {
        let controller = LaunchAnimationController(reducedMotion: { true })
        controller.loadViewIfNeeded()
        var count = 0; controller.onFinish = { count += 1 }
        controller.viewDidAppear(false)
        try await Task.sleep(nanoseconds: 400_000_000)
        controller.viewDidAppear(false)
        XCTAssertEqual(count, 1)
        XCTAssertTrue(controller.finished)
    }
    func testFinalPoseRendersAtCompactAndTallSizes() {
        for size in [CGSize(width: 393, height: 852), CGSize(width: 320, height: 568)] {
            let controller = LaunchAnimationController()
            controller.loadViewIfNeeded(); controller.view.frame = CGRect(origin: .zero, size: size)
            controller.view.layoutIfNeeded(); controller.setFinalPose()
            let image = UIGraphicsImageRenderer(size: size).image { controller.view.layer.render(in: $0.cgContext) }
            let attachment = XCTAttachment(image: image); attachment.name = "Launch final \(Int(size.width))"; attachment.lifetime = .keepAlways; add(attachment)
            XCTAssertEqual(controller.view.accessibilityIdentifier, "launch.animation")
        }
    }
}
