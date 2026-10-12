import XCTest
import UIKit
@testable import MadeRoom

final class InstallationSessionTests: XCTestCase {
    func testOnlyFreshInstallationClearsCredentialsAndConsent() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let marker = directory.appendingPathComponent("installation")
        var signOuts = 0; var resets = 0
        func prepare() throws {
            try InstallationSession.prepare(marker: marker, signOut: { signOuts += 1 }, resetConsent: { resets += 1 })
        }
        try prepare(); try prepare()
        XCTAssertEqual(signOuts, 1); XCTAssertEqual(resets, 1)
        try FileManager.default.removeItem(at: marker)
        try prepare()
        XCTAssertEqual(signOuts, 2); XCTAssertEqual(resets, 2)
    }
    func testFailedSignOutDoesNotMarkInstallationComplete() throws {
        let marker = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        XCTAssertThrowsError(try InstallationSession.prepare(marker: marker, signOut: { throw CocoaError(.fileWriteNoPermission) }, resetConsent: { XCTFail("Must not proceed after sign-out failure") }))
        XCTAssertFalse(FileManager.default.fileExists(atPath: marker.path))
    }
    func testProfileOutboxSurvivesReloadAndRejectsOversizedCopy() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("state.json")
        let store = try RoomStore(url: url)
        try store.saveProfile(name: "Alice", username: "alice.makes", biography: "Hello", location: "Portland")
        let revision = try XCTUnwrap(store.state.profilePendingRevision)
        let reloaded = try RoomStore(url: url)
        XCTAssertEqual(reloaded.state.profilePendingRevision, revision)
        XCTAssertEqual(reloaded.state.profileLocation, "Portland")
        XCTAssertThrowsError(try reloaded.saveProfile(name: String(repeating: "x", count: 81), username: "alice.makes", biography: "", location: ""))
        XCTAssertEqual(reloaded.state.profileName, "Alice")
    }
    func testAvatarIsReducedForPrivateFirestoreDocument() throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1000, height: 600)).image { context in
            UIColor.red.setFill(); context.fill(CGRect(x: 0, y: 0, width: 1000, height: 600))
        }
        let data = try ProfileSync.thumbnail(image)
        let result = try XCTUnwrap(UIImage(data: data))
        XCTAssertLessThanOrEqual(max(result.size.width, result.size.height), 256)
        XCTAssertLessThanOrEqual(data.count, 98304)
    }
}
