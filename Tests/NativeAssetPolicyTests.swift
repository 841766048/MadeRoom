import XCTest
import UIKit
@testable import MadeRoom
final class NativeAssetPolicyTests: XCTestCase {
    func testApplicationDoesNotBundleScreenshotLayoutOrCroppedControls() {
        let bundle = Bundle(for: AppDelegate.self)
        XCTAssertNil(bundle.url(forResource: "screens", withExtension: "json"), "Screens must be authored UIKit, not OCR layout playback")
        XCTAssertNil(bundle.url(forResource: "Artwork", withExtension: nil), "Legacy screenshot fragments must not ship")
        XCTAssertNil(bundle.url(forResource: "content", withExtension: nil), "Publication source files must not ship in the app")
        XCTAssertEqual(EditorialImageCatalog.manifestURL.host, "made-room-20261009.web.app")
    }
    func testRemoteManifestRejectsDuplicateIDsAndUntrustedURLs() throws {
        let valid = ["id":"cover","sha256":String(repeating:"a",count:64),"downloadURL":"https://made-room-20261009.web.app/editorial/cover.png"]
        let data = try JSONSerialization.data(withJSONObject:["images":[valid]])
        XCTAssertEqual(try EditorialImageCatalog.decodeManifest(data).count,1)
        XCTAssertThrowsError(try EditorialImageCatalog.decodeManifest(JSONSerialization.data(withJSONObject:["images":[valid,valid]])))
        var invalid = valid;invalid["downloadURL"] = "https://other.example/cover.png"
        XCTAssertThrowsError(try EditorialImageCatalog.decodeManifest(JSONSerialization.data(withJSONObject:["images":[invalid]])))
    }
    func testTabVectorAssetsArePackagedAtConsistentTemplateSize() throws {
        for index in 0..<5 {
            for selected in [false,true] {
                let image = try XCTUnwrap(RoomTabIcon.image(at:index,selected:selected))
                XCTAssertEqual(image.size,CGSize(width:24,height:24))
                XCTAssertEqual(image.renderingMode,.alwaysTemplate)
            }
        }
    }

}
