import XCTest
@testable import MadeRoom
final class StoreTests: XCTestCase {
    func testPublicationIdentitySurvivesRetryAndChangesWithContent() throws {
        let store = try RoomStore(url: nil)
        try store.saveDraft(title: "Weave", body: "First line\nSecond line", imageName: nil)
        let first = try XCTUnwrap(store.state.draft?.publicationID)
        try store.saveDraft(title: "Weave", body: "First line\nSecond line", imageName: nil)
        XCTAssertEqual(store.state.draft?.publicationID, first)
        try store.saveDraft(title: "New weave", body: "First line\nSecond line", imageName: nil)
        XCTAssertNotEqual(store.state.draft?.publicationID, first)
        let legacy = try JSONDecoder().decode(PostDraft.self, from: Data(#"{"title":"Old draft","body":"Keep my text"}"#.utf8))
        XCTAssertNil(legacy.publicationID)
        XCTAssertEqual(legacy.body, "Keep my text")
    }
    func testCommentsAreSeparatedAndRestored() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("state.json")
        let store = try RoomStore(url: url)
        try store.update { $0.comments = ["An older comment"]; $0.localComments = [LocalComment(id: "comment-1", parentID: "tessa", replyTo: "Tessa", text: "A new reply")] }
        let snapshot = try JSONDecoder().decode(RoomState.self, from: Data(contentsOf: url))
        XCTAssertEqual(snapshot.comments, [])
        XCTAssertNil(snapshot.localComments)
        XCTAssertNotNil(snapshot.commentsFile)
        let restored = try RoomStore(url: url)
        XCTAssertEqual(restored.state.comments, ["An older comment"])
        XCTAssertEqual(restored.state.localComments?.first?.text, "A new reply")
    }
    func testLegacyCommentMigrationPreservesUserText() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("state.json")
        var original = RoomState(); original.comments = ["Keep my original text"]
        try JSONEncoder().encode(original).write(to: url)
        let migrated = try RoomStore(url: url)
        XCTAssertEqual(migrated.state.comments, original.comments)
        XCTAssertNotNil(migrated.state.commentsFile)
    }
    func testEnglishKnowledgeAndImageReferences() throws {
        let items = try KnowledgeCatalog.load(bundle: Bundle(for: AppDelegate.self))
        XCTAssertEqual(items.count, 24)
        XCTAssertEqual(Set(items.map(\.id)).count, items.count)
        for item in items {
            XCTAssertEqual(item.language, "en")
            XCTAssertFalse(item.title.isEmpty)
            for image in item.imageIds { XCTAssertNotNil(TestContent.images[image]) }
        }
    }

    func testProjectCompletionAndSpacePlacementSurviveReload() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("state.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = try RoomStore(url: url)
        let id = try store.createProject(name: "My first weave", sourcePost: "nora-post")
        for _ in 0..<6 { try store.advanceProject(id) }
        try store.placeProject(id, in: "Reading corner")
        let restored = try RoomStore(url: url)
        let project = try XCTUnwrap(restored.state.projects.first { $0.id == id })
        XCTAssertEqual(project.completedSteps, 6)
        XCTAssertEqual(project.space, "Reading corner")
        XCTAssertEqual(project.sourcePost, "nora-post")
        try restored.advanceProject(id)
        XCTAssertEqual(restored.state.projects.first?.completedSteps, 6)
    }
    func testInvalidProjectDoesNotPersistAndUnfinishedCannotBePlaced() throws {
        let store = try RoomStore(url: nil)
        XCTAssertThrowsError(try store.createProject(name: "  ", sourcePost: nil))
        let id = try store.createProject(name: "Weave", sourcePost: nil)
        XCTAssertThrowsError(try store.placeProject(id, in: "Living room"))
        XCTAssertEqual(store.state.projects.count, 1)
    }
    func testDraftAndPreferencesPersistWithoutClaimingRemotePublication() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = try RoomStore(url: url)
        try store.saveDraft(title: "Reading corner", body: "My handmade weave", imageName: nil)
        try store.toggleSaved("D04")
        try store.setPreference("metric", value: true)
        let loaded = try RoomStore(url: url)
        XCTAssertEqual(loaded.state.draft?.body, "My handmade weave")
        XCTAssertTrue(loaded.state.saved.contains("D04"))
        XCTAssertEqual(loaded.state.preferences["metric"], true)
    }
    func testCorruptFileIsNotSilentlyOverwritten() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("bad json".utf8).write(to: url)
        XCTAssertThrowsError(try RoomStore(url: url))
        XCTAssertEqual(try String(contentsOf: url), "bad json")
    }
    func testSpaceRenameMovesPlacementsAndPhotoMetadata() throws {
        let store = try RoomStore(url: nil)
        let id = try store.createProject(name: "Weave", sourcePost: nil)
        for _ in 0..<6 { try store.advanceProject(id) }
        try store.placeProject(id, in: "Reading corner")
        try store.saveSpace(originalName: "Reading corner", name: "Quiet corner", notes: "Morning light")
        XCTAssertEqual(store.state.projects.first?.space, "Quiet corner")
        XCTAssertFalse(store.state.spaces.contains("Reading corner"))
        XCTAssertEqual(store.state.spaceDetails?["Quiet corner"]?.notes, "Morning light")
    }
    func testArchivePreservesProjectAndCollectionRemovalPreservesSavedItem() throws {
        let store = try RoomStore(url: nil)
        let id = try store.createProject(name: "Weave", sourcePost: nil)
        try store.archiveProject(id)
        XCTAssertEqual(store.state.projects.count, 1)
        XCTAssertTrue(store.state.archivedProjects?.contains(id) == true)
        try store.toggleSaved("D04")
        try store.addSavedItem("D04", to: "Weekend")
        try store.removeCollection("Weekend")
        XCTAssertTrue(store.state.saved.contains("D04"))
        XCTAssertFalse(store.state.collections.contains("Weekend"))
    }

    func testProfileFieldsPersistAndInvalidUsernameDoesNotOverwrite() throws {
        let url=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("json")
        defer {try? FileManager.default.removeItem(at:url)}
        let store=try RoomStore(url:url)
        try store.saveProfile(name:"Alex",username:"alex.makes",biography:"A handmade home",location:"Taipei")
        XCTAssertThrowsError(try store.saveProfile(name:"Wrong",username:"a space",biography:"",location:""))
        let loaded=try RoomStore(url:url)
        XCTAssertEqual(loaded.state.profileName,"Alex")
        XCTAssertEqual(loaded.state.profileUsername,"alex.makes")
        XCTAssertEqual(loaded.state.profileLocation,"Taipei")
        XCTAssertEqual(loaded.state.biography,"A handmade home")
        var legacy=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:url)) as? [String:Any])
        legacy.removeValue(forKey:"profileUsername");legacy.removeValue(forKey:"profileLocation")
        try JSONSerialization.data(withJSONObject:legacy).write(to:url)
        let migrated=try RoomStore(url:url)
        XCTAssertEqual(migrated.state.profileName,"Alex")
        XCTAssertNil(migrated.state.profileUsername)
    }

}

// Publication source files are test fixtures only; the application never bundles them.
enum TestContent {
    static func data(_ name: String) throws -> Data {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try Data(contentsOf: root.appendingPathComponent("content/" + name + ".json"))
    }
    static var images: [String: EditorialImageRecord] {
        struct Manifest: Decodable { let images: [EditorialImageRecord] }
        let images = (try? JSONDecoder().decode(Manifest.self, from:data("image-manifest")).images) ?? []
        return Dictionary(uniqueKeysWithValues: images.map { ($0.id,$0) })
    }
}
enum KnowledgeCatalog {
    static func load(bundle: Bundle = .main) throws -> [CraftKnowledge] {
        struct Document: Decodable { let items: [CraftKnowledge] }
        return try ["knowledge-existing", "knowledge-new"].flatMap { try JSONDecoder().decode(Document.self, from:TestContent.data($0)).items }
    }
}
enum CommunityEditorialCatalog {
    static func load() throws -> [CommunityEditorialPost] {
        struct Document: Decodable { let items: [CommunityEditorialPost] }
        return try JSONDecoder().decode(Document.self, from:TestContent.data("community-editorial")).items
    }
}
