import XCTest
import UIKit
@testable import MadeRoom

final class SpaceSyncTests: XCTestCase {
    func testCreateRenameDeleteKeepsOneRemoteIdentity() throws {
        let store = try RoomStore(url: nil)
        try store.saveSpace(originalName: nil, name: "Studio", notes: "Warm light")
        let id = try XCTUnwrap(store.state.spaceIDs?["Studio"])
        XCTAssertNotNil(store.state.spacePending?[id])
        try store.saveSpace(originalName: "Studio", name: "Craft studio", notes: "New notes")
        XCTAssertEqual(store.state.spaceIDs?["Craft studio"], id)
        XCTAssertNil(store.state.deletedSpaces?[id])
        XCTAssertNil(store.state.spaceIDs?["Studio"])
        try store.removeSpace("Craft studio")
        XCTAssertEqual(store.state.deletedSpaces?[id], "Craft studio")
        XCTAssertNotNil(store.state.spacePending?[id])
    }
    func testRemoteRestoresNotesAndPlacedPiecesWithoutQueuingAnEcho() throws {
        let store = try RoomStore(url: nil), id = "remote-space"
        let piece = MakeProject(id: UUID(), name: "Basket", completedSteps: 6, space: "Nook")
        let json = String(decoding: try JSONEncoder().encode([piece]), as: UTF8.self)
        let cloud = CloudSpace(uid: "alice", name: "Nook", notes: "By the window", piecesJSON: json, deleted: false, revision: "a")
        try store.applyCloudSpace(cloud, id: id)
        XCTAssertEqual(store.state.spaceDetails?["Nook"]?.notes, "By the window")
        XCTAssertEqual(store.state.projects.first?.space, "Nook")
        XCTAssertNil(store.state.spacePending?[id])
        var deletion = cloud; deletion.deleted = true; deletion.revision = "b"
        try store.applyCloudSpace(deletion, id: id)
        XCTAssertFalse(store.state.spaces.contains("Nook"))
        XCTAssertNil(store.state.projects.first?.space)
    }
    func testPendingLocalEditWinsOverOldCloudSnapshot() throws {
        let store = try RoomStore(url: nil)
        try store.saveSpace(originalName: nil, name: "Nook", notes: "Local draft")
        let id = try XCTUnwrap(store.state.spaceIDs?["Nook"])
        try store.applyCloudSpace(CloudSpace(uid: "alice", name: "Nook", notes: "Old cloud", piecesJSON: "[]", deleted: false, revision: "old"), id: id)
        XCTAssertEqual(store.state.spaceDetails?["Nook"]?.notes, "Local draft")
    }
    func testOutboxSurvivesRestartAndRejectsDuplicateNames() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("state.json"), store = try RoomStore(url: url)
        try store.saveSpace(originalName: nil, name: "Nook", notes: "Keep this")
        let restored = try RoomStore(url: url)
        XCTAssertEqual(restored.state.spacePending, store.state.spacePending)
        XCTAssertThrowsError(try restored.saveSpace(originalName: nil, name: "Nook", notes: "Duplicate"))
    }
    func testMigrationWaitsForCloudBeforeUploadingUntouchedDefaults() throws {
        let store = try RoomStore(url: nil)
        try store.prepareSpaceSync(meaningfulOnly: true)
        XCTAssertTrue((store.state.spacePending ?? [:]).isEmpty)
        try store.prepareSpaceSync()
        XCTAssertEqual(store.state.spacePending?.count, 2)
    }
}

final class LocalClearRegressionTests: XCTestCase {
    func testClearDoesNotQueueCloudDeletes() throws {
        let store = try RoomStore(url:nil)
        try store.saveSpace(originalName:nil,name:"Studio",notes:"Keep online")
        var sends = 0; store.onSpacesChanged = { sends += 1 }
        try store.clearLocalCache()
        XCTAssertEqual(sends,0)
        XCTAssertTrue(store.state.spacePending?.isEmpty ?? true)
        XCTAssertTrue(store.state.libraryPending?.isEmpty ?? true)
    }
}

final class LibrarySyncTests: XCTestCase {
    func testOutboxRestoresUnassignedProjectsAndDeletesWithoutEcho() throws {
        let url=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("state.json")
        defer { try? FileManager.default.removeItem(at:url.deletingLastPathComponent()) }
        let local=try RoomStore(url:url)
        let id=try local.createProject(name:"Unassigned make",sourcePost:nil)
        let key="project-"+id.uuidString
        let pending=try XCTUnwrap(local.state.libraryPending?[key])
        XCTAssertNil(local.state.projects.first?.space)
        XCTAssertEqual(try RoomStore(url:url).state.libraryPending?[key]?.revision,pending.revision)
        let restored=try RoomStore(url:nil)
        let cloud=CloudLibraryItem(uid:"owner",kind:pending.kind,payload:pending.payload,photo:nil,deleted:false,revision:pending.revision)
        try restored.applyLibrary(cloud,id:key)
        XCTAssertEqual(restored.state.projects.first?.name,"Unassigned make")
        XCTAssertTrue(restored.state.libraryPending?.isEmpty ?? true)
        try restored.update { $0.projects.removeAll() }
        XCTAssertEqual(restored.state.libraryPending?[key]?.deleted,true)
        // A stale server snapshot cannot overwrite a pending local deletion.
        try restored.applyLibrary(cloud,id:key)
        XCTAssertTrue(restored.state.projects.isEmpty)
    }
    func testCollectionsPreferencesAndPhotosRestoreFromCloud() throws {
        let store=try RoomStore(url:nil)
        try store.addSavedItem("post-one",to:"My ideas")
        try store.setPreference("New followers",value:false)
        let target=try RoomStore(url:nil)
        for (key,item) in store.state.libraryPending ?? [:] {
            try target.applyLibrary(CloudLibraryItem(uid:"owner",kind:item.kind,payload:item.payload,photo:nil,deleted:item.deleted,revision:item.revision),id:key)
        }
        XCTAssertTrue(target.state.saved.contains("post-one"))
        XCTAssertEqual(target.state.collectionItems?["My ideas"],["post-one"])
        XCTAssertEqual(target.state.preferences["New followers"],false)
        XCTAssertTrue(target.state.libraryPending?.isEmpty ?? true)
        let filename="library-test-\(UUID().uuidString).jpg"
        let image=UIGraphicsImageRenderer(size:CGSize(width:12,height:12)).image { context in UIColor.red.setFill();context.fill(CGRect(x:0,y:0,width:12,height:12)) }
        let bytes=try XCTUnwrap(image.jpegData(compressionQuality:0.7))
        let payload=try LibraryPersistence.json(LibraryPhoto(projectID:UUID(),filename:filename))
        try target.applyLibrary(CloudLibraryItem(uid:"owner",kind:"photo",payload:payload,photo:bytes,deleted:false,revision:"photo-revision"),id:"photo-1")
        let path=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent(filename)
        defer { try? FileManager.default.removeItem(at:path) }
        XCTAssertEqual(try Data(contentsOf:path),bytes)
    }
    func testOldSpaceSnapshotCannotResurrectDeletedLibraryProject() throws {
        let store=try RoomStore(url:nil)
        try store.update(syncLibrary:false) { $0.libraryMigrationComplete=true }
        let old=MakeProject(id:UUID(),name:"Deleted make",space:"Studio")
        let cloud=CloudSpace(uid:"owner",name:"Studio",notes:"",piecesJSON:try LibraryPersistence.json([old]),beforePhoto:nil,afterPhoto:nil,deleted:false,revision:"space-v1",planJSON:"{}")
        try store.applyCloudSpace(cloud,id:"studio")
        XCTAssertTrue(store.state.projects.isEmpty)
        XCTAssertTrue(store.state.libraryPending?.isEmpty ?? true)
    }
    func testMigrationDoesNotOverwriteRemoteKeysOrUntouchedDefaults() throws {
        let store=try RoomStore(url:nil)
        try store.prepareLibraryMigration(remoteIDs:[])
        XCTAssertTrue(store.state.libraryPending?.isEmpty ?? true)
        XCTAssertEqual(store.state.libraryMigrationComplete,true)
    }
}
