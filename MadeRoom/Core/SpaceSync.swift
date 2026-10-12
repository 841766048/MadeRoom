import UIKit
import FirebaseFirestore
import FirebaseAuth
import CryptoKit

struct CloudSpace: Codable {
    var uid: String
    var name: String
    var notes: String
    var piecesJSON: String
    var beforePhoto: Data?
    var afterPhoto: Data?
    var deleted: Bool
    var revision: String
    var planJSON: String? = nil
}

enum SpacePersistence {
    static func legacyID(_ name: String) -> String {
        SHA256.hash(data: Data(name.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    static func photo(_ filename: String?) throws -> Data? {
        guard let filename else { return nil }
        guard filename == URL(fileURLWithPath: filename).lastPathComponent else { throw CocoaError(.fileReadCorruptFile) }
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)
        guard let image = UIImage(contentsOfFile: url.path), image.size.width > 0, image.size.height > 0 else { throw CocoaError(.fileReadCorruptFile) }
        let ratio = min(1, 768 / max(image.size.width, image.size.height))
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        let bounds = CGRect(x: 0, y: 0, width: image.size.width * ratio, height: image.size.height * ratio)
        let resized = UIGraphicsImageRenderer(size: bounds.size, format: format).image { context in
            UIColor.white.setFill(); context.fill(bounds); image.draw(in: bounds)
        }
        for quality in [0.8, 0.6, 0.4, 0.2] {
            if let data = resized.jpegData(compressionQuality: quality), data.count <= 196608 { return data }
        }
        throw CocoaError(.fileWriteOutOfSpace)
    }
    static func record(state: RoomState, uid: String, id: String, revision: String) throws -> CloudSpace {
        let name = state.spaceIDs?.first(where: { $0.value == id })?.key ?? state.deletedSpaces?[id] ?? "Deleted space"
        let deleted = state.deletedSpaces?[id] != nil
        let details = state.spaceDetails?[name] ?? SpaceDetails()
        let pieces = deleted ? [] : state.projects.filter { $0.space == name }
        let json = String(decoding: try JSONEncoder().encode(pieces), as: UTF8.self)
        guard name.count <= 80, details.notes.count <= 4000, json.utf8.count <= 100000 else { throw SpaceSyncError.tooLarge }
        return CloudSpace(uid: uid, name: name, notes: deleted ? "" : details.notes, piecesJSON: json,
                          beforePhoto: deleted ? nil : try photo(details.beforePhoto), afterPhoto: deleted ? nil : try photo(details.afterPhoto), deleted: deleted, revision: revision, planJSON: String(decoding: try JSONEncoder().encode(details.plan ?? [:]), as: UTF8.self))
    }
}
enum SpaceSyncError: LocalizedError {
    case tooLarge, duplicateName
    var errorDescription: String? {
        switch self {
        case .tooLarge: return "Use up to 80 characters for the space name and 4,000 for notes. This space may contain too much data to sync."
        case .duplicateName: return "A space with this name already exists. Choose another name."
        }
    }
}

/// Per-space revisions, not a whole-library overwrite. Local edits win until acknowledged.
final class SpaceSync {
    private let uid: String
    private let store: RoomStore
    private let collection: CollectionReference
    private var listener: ListenerRegistration?
    private var reading: NetworkLoadingTicket?
    private var writing: NetworkLoadingTicket?
    private var stopped = false
    private var sending = false
    private(set) var ready = false
    private(set) var status = "Loading spaces…"
    var onChange: (() -> Void)?
    private var authorized: Bool { !stopped && AccountService.auth.currentUser?.uid == uid }
    init(uid: String, store: RoomStore) {
        self.uid = uid; self.store = store
        collection = CommentDatabase.shared.collection("users").document(uid).collection("spaces")
    }
    func start() {
        do { try store.prepareSpaceSync(meaningfulOnly: true) }
        catch { status = "Could not prepare local spaces. Tap Retry."; onChange?(); return }
        store.onSpacesChanged = { [weak self] in self?.flush() }
        let loading = NetworkLoading.shared.begin(); reading = loading
        listener = collection.addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
            if error != nil || snapshot?.metadata.isFromCache == false { loading.finish() }
            guard let self, self.authorized else { return }
            if error != nil { self.status = "Could not sync spaces. Tap Retry."; self.onChange?(); return }
            guard let snapshot, !snapshot.metadata.isFromCache, !snapshot.metadata.hasPendingWrites else { return }
            do {
                for doc in snapshot.documents {
                    let value = try doc.data(as: CloudSpace.self)
                    guard value.uid == self.uid else { continue }
                    try self.store.applyCloudSpace(value, id: doc.documentID)
                }
                self.ready = true
                // After server hydration, migrate spaces that only exist locally.
                try self.store.prepareSpaceSync()
                self.status = (self.store.state.spacePending ?? [:]).isEmpty ? "Spaces synced" : "Saved on device · Waiting to sync"
                self.onChange?(); self.flush()
            } catch { self.status = "Could not load spaces. Tap Retry."; self.onChange?() }
        }
        flush()
    }
    func stop() {
        stopped = true; listener?.remove(); listener = nil
        reading?.finish(); writing?.finish(); store.onSpacesChanged = nil; onChange = nil
    }
    deinit { listener?.remove(); reading?.finish(); writing?.finish() }
    func retry() { listener?.remove(); reading?.finish(); start() }
    func flush() {
        guard authorized, !sending, let (id, revision) = store.state.spacePending?.sorted(by: { $0.key < $1.key }).first else { return }
        do {
            let record = try SpacePersistence.record(state: store.state, uid: uid, id: id, revision: revision)
            var fields = try Firestore.Encoder().encode(record)
            fields["beforePhoto"] = record.beforePhoto.map { $0 as Any } ?? NSNull()
            fields["afterPhoto"] = record.afterPhoto.map { $0 as Any } ?? NSNull()
            fields["updatedAt"] = FieldValue.serverTimestamp()
            sending = true; status = "Saved on device · Waiting to sync"; onChange?()
            let loading = NetworkLoading.shared.begin(); writing = loading
            collection.document(id).setData(fields) { [weak self] error in
                defer { loading.finish() }
                guard let self, self.authorized else { return }; self.sending = false
                guard error == nil else { self.status = "Spaces sync failed. Tap Retry."; self.onChange?(); return }
                do {
                    try self.store.update(syncSpaces: false) { state in
                        if state.spacePending?[id] == revision { state.spacePending?.removeValue(forKey: id) }
                    }
                    self.status = (self.store.state.spacePending ?? [:]).isEmpty ? "Spaces synced" : "Saved on device · Waiting to sync"
                    self.onChange?(); self.flush()
                } catch { self.status = "Could not save sync status. Tap Retry."; self.onChange?() }
            }
        } catch { status = error.localizedDescription + " Tap Retry."; onChange?() }
    }
}

// MARK: - Private projects, photos, collections and preferences
struct PendingLibraryItem: Codable, Equatable {
    var kind: String
    var payload: String
    var photoFilename: String?
    var deleted = false
    var revision = UUID().uuidString
}
struct CloudLibraryItem: Codable {
    let uid: String
    let kind: String
    let payload: String
    let photo: Data?
    let deleted: Bool
    let revision: String
}
struct LibraryProject: Codable { let project: MakeProject; let archived: Bool; let photos: [String] }
struct LibraryCollection: Codable { let name: String; let items: [String] }
struct LibraryPhoto: Codable { let projectID: UUID; let filename: String }
enum LibraryPersistence {
    static func json<T: Encodable>(_ value:T) throws -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return String(decoding:try encoder.encode(value),as:UTF8.self)
    }
    static func decode<T: Decodable>(_ type:T.Type,_ text:String) throws -> T { try JSONDecoder().decode(type,from:Data(text.utf8)) }
    static func key(_ prefix:String,_ value:String) -> String { prefix + "-" + SpacePersistence.legacyID(value) }
    static func items(_ state:RoomState) throws -> [String:PendingLibraryItem] {
        var result:[String:PendingLibraryItem] = [:]
        func put(_ id:String,_ kind:String,_ payload:String,_ photo:String? = nil) { result[id] = PendingLibraryItem(kind:kind,payload:payload,photoFilename:photo,revision:"") }
        for project in state.projects {
            let photos = state.projectPhotos?[project.id.uuidString] ?? []
            put("project-" + project.id.uuidString,"project",try json(LibraryProject(project:project,archived:state.archivedProjects?.contains(project.id) == true,photos:photos)))
            for filename in photos { put(key("photo",filename),"photo",try json(LibraryPhoto(projectID:project.id,filename:filename)),filename) }
        }
        for id in state.saved { put(key("saved",id),"saved",try json(id)) }
        for name in state.collections {
            put(key("collection",name),"collection",try json(LibraryCollection(name:name,items:state.collectionItems?[name] ?? [])))
        }
        let preferences = state.preferences.filter { !$0.key.hasPrefix("spaceRevision.") }
        put("preferences","preferences",try json(preferences))
        return result
    }
    static func queueChanges(from old:RoomState,to candidate:inout RoomState) throws -> Bool {
        let before = try items(old), after = try items(candidate)
        var pending = candidate.libraryPending ?? [:], changed = false
        for key in Set(before.keys).union(after.keys) where before[key] != after[key] {
            guard var item = after[key] ?? before[key] else { continue }
            item.deleted = after[key] == nil; item.revision = UUID().uuidString
            pending[key] = item; changed = true
        }
        candidate.libraryPending = pending
        return changed
    }
}
extension RoomStore {
    /// Never derives tombstones or revisions from a local-only clear.
    func clearLocalCache() throws {
        var files=Set((state.projectPhotos ?? [:]).values.flatMap{$0})
        for details in (state.spaceDetails ?? [:]).values { if let f=details.beforePhoto { files.insert(f) };if let f=details.afterPhoto { files.insert(f) } }
        if let f=state.profilePhoto { files.insert(f) };if let f=state.draft?.imageName { files.insert(f) }
        try update(syncSpaces:false,syncLibrary:false) { $0 = RoomState() }
        let folder=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
        for file in files where !file.isEmpty && file == URL(fileURLWithPath:file).lastPathComponent {
            let url=folder.appendingPathComponent(file)
            if FileManager.default.fileExists(atPath:url.path) { try FileManager.default.removeItem(at:url) }
        }
    }
    func prepareLibraryMigration(remoteIDs:Set<String>) throws {
        guard state.libraryMigrationComplete != true else { return }
        let local = try LibraryPersistence.items(state)
        try update(syncSpaces:false,syncLibrary:false) { candidate in
            var pending = candidate.libraryPending ?? [:]
            for (id,var item) in local where !remoteIDs.contains(id) && pending[id] == nil {
                if item.kind == "preferences", item.payload == "{}" { continue }
                if item.kind == "collection", let value = try? LibraryPersistence.decode(LibraryCollection.self,item.payload), value.name == "Cozy corners", value.items.isEmpty { continue }
                item.revision = UUID().uuidString; pending[id] = item
            }
            candidate.libraryPending = pending; candidate.libraryMigrationComplete = true
        }
    }
    func applyLibrary(_ item:CloudLibraryItem,id:String) throws {
        guard state.libraryPending?[id] == nil, state.libraryRevisions?[id] != item.revision else { return }
        var photo: LibraryPhoto?
        if item.kind == "photo", !item.deleted {
            let value = try LibraryPersistence.decode(LibraryPhoto.self,item.payload)
            guard value.filename == URL(fileURLWithPath:value.filename).lastPathComponent,
                  !value.filename.isEmpty, let bytes = item.photo, bytes.count <= 196608,
                  UIImage(data:bytes) != nil else { throw CocoaError(.fileReadCorruptFile) }
            let folder = FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
            try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
            try bytes.write(to:folder.appendingPathComponent(value.filename),options:.atomic); photo = value
        }
        try update(syncSpaces:false,syncLibrary:false) { candidate in
            switch item.kind {
            case "project":
                let value = try LibraryPersistence.decode(LibraryProject.self,item.payload)
                candidate.projects.removeAll { $0.id == value.project.id }
                candidate.archivedProjects?.remove(value.project.id)
                if item.deleted { candidate.projectPhotos?.removeValue(forKey:value.project.id.uuidString) }
                else {
                    candidate.projects.append(value.project)
                    if value.archived { var archive = candidate.archivedProjects ?? []; archive.insert(value.project.id); candidate.archivedProjects = archive }
                    var photos = candidate.projectPhotos ?? [:];photos[value.project.id.uuidString] = value.photos; candidate.projectPhotos = photos
                }
            case "saved":
                let value = try LibraryPersistence.decode(String.self,item.payload)
                if item.deleted { candidate.saved.remove(value) } else { candidate.saved.insert(value) }
            case "collection":
                let value = try LibraryPersistence.decode(LibraryCollection.self,item.payload)
                candidate.collections.removeAll { $0 == value.name }
                if item.deleted { candidate.collectionItems?.removeValue(forKey:value.name) }
                else { candidate.collections.append(value.name);var items = candidate.collectionItems ?? [:];items[value.name] = value.items;candidate.collectionItems = items }
            case "preferences":
                let remote = try LibraryPersistence.decode([String:Bool].self,item.payload)
                let local = candidate.preferences.filter { $0.key.hasPrefix("spaceRevision.") }
                candidate.preferences = local.merging(item.deleted ? [:] : remote) { _,new in new }
            case "photo": _ = photo // Project records own ordering and deletion of their photo references.
            default: throw CocoaError(.fileReadCorruptFile)
            }
            var revisions = candidate.libraryRevisions ?? [:];revisions[id] = item.revision;candidate.libraryRevisions = revisions
        }
    }
}
final class LibrarySync {
    private let uid:String, store:RoomStore
    private let collection:CollectionReference
    private var listener:ListenerRegistration?
    private var stopped = false, started = false, ready = false, sending = false
    private var ticket:NetworkLoadingTicket?
    private(set) var status = "Loading account data…"
    var onChange:(()->Void)?
    var hasPending:Bool { !(store.state.libraryPending ?? [:]).isEmpty }
    private var authorized:Bool { !stopped && AccountService.auth.currentUser?.uid == uid }
    init(uid:String,store:RoomStore) { self.uid=uid;self.store=store;collection=CommentDatabase.shared.collection("users").document(uid).collection("library") }
    func start() {
        guard authorized, !started else { return };started=true
        store.onLibraryChanged = { [weak self] in self?.flush() }
        listener = collection.addSnapshotListener(includeMetadataChanges:true) { [weak self] snapshot,error in
            guard let self,self.authorized else { return }
            guard let snapshot,error == nil else { self.status="Account sync failed. Tap Retry.";self.onChange?();return }
            guard !snapshot.metadata.isFromCache,!snapshot.metadata.hasPendingWrites else { return }
            do {
                for document in snapshot.documents {
                    let value = try document.data(as:CloudLibraryItem.self)
                    guard value.uid == self.uid else { throw CocoaError(.fileReadCorruptFile) }
                    try self.store.applyLibrary(value,id:document.documentID)
                }
                try self.store.prepareLibraryMigration(remoteIDs:Set(snapshot.documents.map(\.documentID)))
                self.ready=true;self.status=self.hasPending ? "Waiting to sync" : "Account synced";self.onChange?();self.flush()
            } catch { self.status="Account sync failed. Tap Retry.";self.onChange?() }
        }
    }
    func retry() { listener?.remove();started=false;start() }
    func flush() {
        guard authorized,ready,!sending,let (id,item)=store.state.libraryPending?.sorted(by:{$0.key < $1.key}).first else { return }
        do {
            let photo = item.deleted ? nil : try SpacePersistence.photo(item.photoFilename)
            guard item.payload.utf8.count <= 400000 else { throw SpaceSyncError.tooLarge }
            let ref=collection.document(id)
            let fields:[String:Any] = ["uid":uid,"kind":item.kind,"payload":item.payload,"photo":photo.map{$0 as Any} ?? NSNull(),"deleted":item.deleted,"revision":item.revision,"updatedAt":FieldValue.serverTimestamp()]
            sending=true;status="Waiting to sync";onChange?()
            let loading=NetworkLoading.shared.begin();ticket=loading
            ref.setData(fields) { [weak self] error in
                defer { loading.finish() }
                guard let self,self.authorized else { return };self.sending=false
                if error != nil { self.status="Account sync failed. Tap Retry.";self.onChange?();return }
                do {
                    try self.store.update(syncSpaces:false,syncLibrary:false) { state in
                        if state.libraryPending?[id]?.revision == item.revision {
                            state.libraryPending?.removeValue(forKey:id)
                            var revisions=state.libraryRevisions ?? [:];revisions[id]=item.revision;state.libraryRevisions=revisions
                        }
                    }
                    self.status=self.hasPending ? "Waiting to sync" : "Account synced";self.onChange?();self.flush()
                } catch { self.status="Account sync failed. Tap Retry.";self.onChange?() }
            }
        } catch { status=error.localizedDescription;onChange?() }
    }
    func stop() { stopped=true;listener?.remove();listener=nil;store.onLibraryChanged=nil;onChange=nil;ticket?.finish() }
    deinit { listener?.remove();ticket?.finish() }
}
