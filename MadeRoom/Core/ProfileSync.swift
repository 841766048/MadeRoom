import UIKit
import FirebaseAuth
import FirebaseFirestore

/// Private per-user profile. A persisted revision keeps unsent local edits across launches.
final class ProfileSync {
    private let uid: String
    private let store: RoomStore
    private let document: DocumentReference
    private var listener: ListenerRegistration?
    private var readLoading: NetworkLoadingTicket?
    private var writeLoading: NetworkLoadingTicket?
    private var stopped = false
    private(set) var sending = false
    private(set) var status = "Loading profile…"
    var onChange: (() -> Void)?
    init(uid: String, store: RoomStore) {
        self.uid = uid; self.store = store
        document = CommentDatabase.shared.collection("users").document(uid)
    }
    private var authorized: Bool { !stopped && AccountService.auth.currentUser?.uid == uid }
    func start() {
        readLoading?.finish()
        let loading = NetworkLoading.shared.begin(); readLoading = loading
        listener = document.addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
            if error != nil || snapshot?.metadata.isFromCache == false { loading.finish() }
            guard let self, self.authorized else { return }
            if let error { self.status = "Could not sync profile. Tap Retry."; self.onChange?(); print("Profile listener: \((error as NSError).code)"); return }
            guard let snapshot, !snapshot.metadata.hasPendingWrites, !snapshot.metadata.isFromCache else { return }
            guard self.store.state.profilePendingRevision == nil else { self.flush(); return }
            do {
                if snapshot.exists {
                    let profile = try snapshot.data(as: CloudProfile.self)
                    guard profile.uid == self.uid else { return }
                    try self.store.update {
                        $0.profileName = profile.displayName; $0.profileUsername = profile.username
                        $0.biography = profile.biography; $0.profileLocation = profile.location
                        $0.profileAvatarData = profile.avatar; $0.profilePhoto = nil
                    }
                    self.status = "Profile synced"
                } else { self.status = "Edit your profile to save it to your account." }
            } catch { self.status = "Could not load profile. Tap Retry." }
            self.onChange?()
        }
        flush()
    }
    func stop() { readLoading?.finish(); writeLoading?.finish(); stopped = true; listener?.remove(); listener = nil; onChange = nil }
    deinit { listener?.remove(); readLoading?.finish(); writeLoading?.finish() }
    func flush() {
        guard authorized, !sending, let revision = store.state.profilePendingRevision else { return }
        let state = store.state
        sending = true; status = "Saved on device · Waiting to sync"; onChange?()
        let fields: [String: Any] = ["uid": uid, "displayName": state.profileName,
            "username": state.profileUsername ?? "member", "biography": state.biography,
            "location": state.profileLocation ?? "", "avatar": state.profileAvatarData.map { $0 as Any } ?? NSNull(),
            "revision": revision, "updatedAt": FieldValue.serverTimestamp()]
        let loading = NetworkLoading.shared.begin(); writeLoading = loading
        document.setData(fields) { [weak self] error in
            defer { loading.finish() }
            guard let self, self.authorized else { return }
            self.sending = false
            if error != nil { self.status = "Profile sync failed. Tap Retry."; self.onChange?(); return }
            do {
                if self.store.state.profilePendingRevision == revision {
                    try self.store.update { $0.profilePendingRevision = nil }
                }
                self.status = "Profile synced"
                self.onChange?()
                self.flush()
            } catch { self.status = "Could not save sync status. Tap Retry."; self.onChange?() }
        }
    }
    func retry() {
        guard authorized else { return }
        if store.state.profilePendingRevision != nil { flush() }
        else { listener?.remove(); start() }
    }
    static func thumbnail(_ image: UIImage) throws -> Data {
        guard image.size.width > 0, image.size.height > 0 else { throw CocoaError(.fileReadCorruptFile) }
        let scale = min(1, 256 / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill(); context.fill(CGRect(origin: .zero, size: size))
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let data = resized.jpegData(compressionQuality: 0.75), data.count <= 98304 else { throw CocoaError(.fileWriteOutOfSpace) }
        return data
    }
}
private struct CloudProfile: Decodable {
    let uid: String
    let displayName: String
    let username: String
    let biography: String
    let location: String
    let avatar: Data?
}

// Account-scoped circle membership shares the existing authenticated database.
struct CircleMembershipState {
    var joined: Set<String> = []
    var pending: Set<String> = []
    var ready = false
    mutating func receive(_ joined: Set<String>) { self.joined = joined; ready = true }
    mutating func begin(_ id: String) -> Bool {
        guard ready, !pending.contains(id) else { return false }
        pending.insert(id); return true
    }
    mutating func complete(_ id: String, joined desired: Bool, succeeded: Bool) {
        pending.remove(id)
        guard succeeded else { return }
        if desired { joined.insert(id) } else { joined.remove(id) }
    }
}

struct RoomCircle {
    let id: String
    let title: String
    let image: String
    let summary: String
    static let all = [
        RoomCircle(id: "craft", title: "Craft", image: "pottery", summary: "Learn, make and get messy together."),
        RoomCircle(id: "small-spaces", title: "Small spaces", image: "space-entry", summary: "Big ideas for smaller homes."),
        RoomCircle(id: "weaving", title: "Weaving", image: "weaving-maker", summary: "A cozy corner for all things yarn, loom and fiber. Share your makes and find inspiration together.")
    ]
}

final class CircleMembershipSync {
    private let uid: String
    private let database: Firestore
    private let collection: CollectionReference
    private var listener: ListenerRegistration?
    private var stopped = false
    private var listenerGeneration = 0
    private var tickets: [String: NetworkLoadingTicket] = [:]
    private(set) var state = CircleMembershipState()
    private(set) var status = "Loading circle membership…"
    var onChange: (() -> Void)?
    private var authorized: Bool { !stopped && AccountService.auth.currentUser?.uid == uid }

    init(uid: String) {
        self.uid = uid
        database = CommentDatabase.shared
        collection = database.collection("users").document(uid).collection("circles")
    }
    func start() {
        guard authorized else { return }
        listener?.remove(); listenerGeneration += 1
        let generation = listenerGeneration
        state.ready = false; status = "Loading circle membership…"; onChange?()
        listener = collection.limit(to: 10).addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
            guard let self, self.authorized, self.listenerGeneration == generation else { return }
            guard error == nil, let snapshot else {
                self.state.ready = false; self.status = "Could not load circle membership. Tap Retry."; self.onChange?(); return
            }
            guard !snapshot.metadata.isFromCache, !snapshot.metadata.hasPendingWrites else {
                self.state.ready = false; self.status = "Connect to load circle membership."; self.onChange?(); return
            }
            var joined = Set<String>()
            for document in snapshot.documents {
                let data = document.data()
                guard data["uid"] as? String == self.uid,
                      data["circleID"] as? String == document.documentID,
                      RoomCircle.all.contains(where: { $0.id == document.documentID }),
                      let member = data["joined"] as? Bool else {
                    self.state.ready = false; self.status = "Could not load circle membership. Tap Retry."; self.onChange?(); return
                }
                if member { joined.insert(document.documentID) }
            }
            self.state.receive(joined); self.status = "Membership synced with your account."; self.onChange?()
        }
    }
    func setJoined(_ desired: Bool, circleID: String, completion: ((Bool) -> Void)? = nil) {
        guard authorized, RoomCircle.all.contains(where: { $0.id == circleID }), state.begin(circleID) else { completion?(false); return }
        status = desired ? "Joining circle…" : "Leaving circle…"; onChange?()
        let reference = collection.document(circleID)
        let uid = self.uid
        let loading = NetworkLoading.shared.begin(); tickets[circleID] = loading
        // Reading inside the transaction requires an online server response.
        // Transactions are not queued as successful offline membership changes.
        database.runTransaction({ transaction, errorPointer -> Any? in
            do {
                _ = try transaction.getDocument(reference)
                transaction.setData(["uid": uid, "circleID": circleID, "joined": desired,
                                     "updatedAt": FieldValue.serverTimestamp()], forDocument: reference)
                return nil
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }) { [weak self] _, error in
            loading.finish()
            guard let self, self.authorized else { return }
            self.tickets.removeValue(forKey: circleID)
            self.state.complete(circleID, joined: desired, succeeded: error == nil)
            self.status = error == nil ? "Membership synced with your account." : "Circle update failed. Check your connection and try again."
            self.onChange?(); completion?(error == nil)
        }
    }
    func stop() {
        stopped = true; listenerGeneration += 1; listener?.remove(); listener = nil
        tickets.values.forEach { $0.finish() }; tickets.removeAll()
        state = CircleMembershipState(); onChange = nil
    }
    deinit { listener?.remove(); tickets.values.forEach { $0.finish() } }
}

struct PublicCreator: Decodable {
    let uid: String
    let displayName: String
    let biography: String
    let avatarID: String
    let isExample: Bool
}

/// Server snapshots are authoritative. Local prototype follows are deliberately ignored.
final class CommunitySync {
    let uid: String
    private let database = CommentDatabase.shared
    private var listeners: [ListenerRegistration] = []
    private var watched = Set<String>()
    private var stopped = false
    private(set) var creators: [String: PublicCreator] = [:]
    private(set) var posts: [CommunityEditorialPost] = []
    private var editorialPosts: [CommunityEditorialPost] = []
    private var publicMemberPosts: [MemberPost] = []
    private(set) var myPosts: [MemberPost] = []
    private var editorialReady = false
    private var publicReady = false
    private(set) var myPostsReady = false
    private(set) var publishing = false
    private var publicationLoading: NetworkLoadingTicket?
    private(set) var following: [String: Set<String>] = [:]
    private(set) var followers: [String: Set<String>] = [:]
    private(set) var pending = Set<String>()
    private(set) var feedReady = false
    private(set) var status = "Loading community…"
    var onChange: (() -> Void)?
    init(uid: String) { self.uid = uid }
    private var authorized: Bool { !stopped && AccountService.auth.currentUser?.uid == uid }
    func start(name: String, biography: String) {
        publishProfile(name: name, biography: biography, createOnly: true)
        listeners.append(database.collection("publicProfiles").limit(to: 100).addSnapshotListener { [weak self] snapshot, error in
            guard let self, self.authorized else { return }
            if let snapshot { for doc in snapshot.documents { if let person = try? doc.data(as: PublicCreator.self) { self.creators[person.uid] = person } } }
            if error != nil { self.status = "Community could not sync. Tap Retry." }
            self.onChange?()
        })
        listeners.append(database.collection("communityPosts").order(by: "catalogOrder").limit(to: 100).addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
            guard let self, self.authorized else { return }
            if error != nil { self.status = "Community could not sync. Tap Retry."; self.feedReady = false }
            else if let snapshot, !snapshot.metadata.isFromCache, !snapshot.metadata.hasPendingWrites {
                do { self.editorialPosts = try snapshot.documents.map { try $0.data(as: CommunityEditorialPost.self) }; self.editorialReady = true; self.mergePosts(); self.status = "" }
                catch { self.feedReady = false; self.status = "Community could not load. Tap Retry." }
            }
            self.onChange?()
        })
        listenToMemberPosts()
        watch(uid)
    }
    private func mergePosts() {
        var members = Dictionary(uniqueKeysWithValues: publicMemberPosts.map { ($0.id, $0) })
        for post in myPosts where post.visibility == "public" { members[post.id] = post }
        posts = members.values.sorted { $0.createdAt > $1.createdAt }.map(\.presentation) + editorialPosts
        feedReady = editorialReady && publicReady
    }
    private func listenToMemberPosts() {
        for own in [false, true] {
            let query = database.collection("memberPosts").whereField(own ? "authorUID" : "visibility", isEqualTo: own ? uid : "public").order(by: "createdAt", descending: true).limit(to:50)
            listeners.append(query.addSnapshotListener(includeMetadataChanges:true) { [weak self] snapshot, error in
                guard let self, self.authorized else { return }
                if error != nil { self.status = "Posts could not sync. Tap Retry."; if own { self.myPostsReady = false } else { self.publicReady = false } }
                else if let snapshot, !snapshot.metadata.isFromCache, !snapshot.metadata.hasPendingWrites {
                    do {
                        let items = try snapshot.documents.map { try $0.data(as: MemberPost.self) }
                        if own { self.myPosts = items; self.myPostsReady = true } else { self.publicMemberPosts = items; self.publicReady = true }
                        self.status = ""
                    } catch { self.status = "Posts could not sync. Tap Retry." }
                }
                self.mergePosts(); self.onChange?()
            })
        }
    }
    func publish(_ draft: PostDraft, isPublic: Bool, completion: @escaping (Result<MemberPost, Error>) -> Void) {
        guard authorized else { completion(.failure(PublicationError.unavailable)); return }
        guard !publishing else { return }
        let title = draft.title.trimmingCharacters(in:.whitespacesAndNewlines)
        let body = draft.body.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !title.isEmpty, title.count <= 120, !body.isEmpty, body.count <= 4000,
              let id = draft.publicationID else { completion(.failure(PublicationError.invalidContent)); return }
        let photo: Data?
        do { photo = try SpacePersistence.photo(draft.imageName) } catch { completion(.failure(error)); return }
        publishing = true; onChange?()
        let loading = NetworkLoading.shared.begin(); publicationLoading = loading
        let owner = uid, visibility = isPublic ? "public" : "private"
        let reference = database.collection("memberPosts").document(id)
        let profile = database.collection("publicProfiles").document(owner)
        database.runTransaction({ transaction, errorPointer in
            do {
                let existing = try transaction.getDocument(reference)
                if existing.exists {
                    let old = try existing.data(as:MemberPost.self)
                    guard old.authorUID == owner, old.title == title, old.body == body, old.visibility == visibility, old.photoData == photo else { throw PublicationError.changed }
                    return nil
                }
                let author = try transaction.getDocument(profile)
                guard let name = author.data()?["displayName"] as? String else { throw PublicationError.unavailable }
                transaction.setData(["id":id,"authorUID":owner,"authorName":name,"title":title,"body":body,"photoData":photo.map { $0 as Any } ?? NSNull(),"visibility":visibility,"createdAt":FieldValue.serverTimestamp()],forDocument:reference)
            } catch { errorPointer?.pointee = error as NSError }
            return nil
        }) { [weak self] _, error in
            guard let self, self.authorized else { loading.finish(); return }
            if let error { self.publishing = false; loading.finish(); self.onChange?(); completion(.failure(error)); return }
            reference.getDocument(source:.server) { [weak self] snapshot, error in
                defer { loading.finish() }
                guard let self, self.authorized else { return }
                self.publishing = false; self.onChange?()
                do {
                    if let error { throw error }
                    guard let snapshot else { throw PublicationError.unavailable }
                    completion(.success(try snapshot.data(as:MemberPost.self)))
                } catch { completion(.failure(error)) }
            }
        }
    }
    func deletePost(_ id: String, completion: @escaping (Bool) -> Void) {
        guard authorized else { completion(false); return }
        let ref = database.collection("memberPosts").document(id), owner = uid
        database.runTransaction({ transaction, errorPointer in
            do {
                let old = try transaction.getDocument(ref)
                if old.exists {
                    guard old.data()?["authorUID"] as? String == owner else { throw PublicationError.unavailable }
                    transaction.deleteDocument(ref)
                }
            } catch { errorPointer?.pointee = error as NSError }
            return nil
        }) { [weak self] _, error in
            guard let self, self.authorized else { return }
            completion(error == nil)
        }
    }
    func publishProfile(name: String, biography: String, createOnly: Bool = false) {
        guard authorized else { return }
        let ref = database.collection("publicProfiles").document(uid)
        let owner = uid
        database.runTransaction({ transaction, errorPointer in
            do {
                let snapshot = try transaction.getDocument(ref)
                if createOnly && snapshot.exists { return nil }
                // Seeded editorial identities remain controlled by the publisher.
                if snapshot.data()?["isExample"] as? Bool == true { return nil }
                transaction.setData(["uid": owner, "displayName": name, "biography": biography, "avatarID": "studio", "isExample": false], forDocument: ref)
            } catch { errorPointer?.pointee = error as NSError }
            return nil
        }) { [weak self] _, error in
            guard let self, self.authorized else { return }
            if error != nil { self.status = "Public profile could not sync. Tap Retry."; self.onChange?() }
        }
    }
    func watch(_ person: String) {
        guard authorized, watched.insert(person).inserted else { return }
        loadCreator(person)
        for outgoing in [true, false] {
            let query = database.collection("socialFollows").whereField(outgoing ? "followerUID" : "followingUID", isEqualTo: person)
            listeners.append(query.addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
                guard let self, self.authorized else { return }
                guard error == nil, let snapshot, !snapshot.metadata.isFromCache, !snapshot.metadata.hasPendingWrites else {
                    if outgoing { self.following[person] = nil } else { self.followers[person] = nil }
                    if error != nil { self.status = "Relationships could not sync. Tap Retry." }
                    self.onChange?(); return
                }
                let ids = Set(snapshot.documents.compactMap { $0.data()[outgoing ? "followingUID" : "followerUID"] as? String })
                if outgoing { self.following[person] = ids } else { self.followers[person] = ids }
                for id in ids { self.loadCreator(id) }
                self.onChange?()
            })
        }
    }
    private func loadCreator(_ id: String) {
        guard creators[id] == nil else { return }
        database.collection("publicProfiles").document(id).getDocument { [weak self] snapshot, _ in
            guard let self, self.authorized, let person = try? snapshot?.data(as: PublicCreator.self) else { return }
            self.creators[id] = person; self.onChange?()
        }
    }
    func toggleFollow(_ target: String) {
        guard authorized, target != uid, let own = following[uid], creators[target] != nil, pending.insert(target).inserted else { return }
        let join = !own.contains(target), source = uid
        let ref = database.collection("socialFollows").document(source + ":" + target)
        onChange?()
        database.runTransaction({ transaction, errorPointer in
            do {
                let snapshot = try transaction.getDocument(ref)
                if join && !snapshot.exists {
                    transaction.setData(["followerUID": source, "followingUID": target, "createdAt": FieldValue.serverTimestamp()], forDocument: ref)
                    InboxWriter.write(transaction: transaction, actor: source, recipient: target, kind: "follow", sourcePath: ref.path)
                }
                else if !join && snapshot.exists { transaction.deleteDocument(ref) }
            } catch { errorPointer?.pointee = error as NSError }
            return nil
        }) { [weak self] _, error in
            guard let self, self.authorized else { return }
            self.pending.remove(target)
            self.status = error == nil ? "" : "Follow could not be updated. Please try again online."
            self.onChange?()
        }
    }
    func retry(name: String, biography: String) {
        guard authorized else { return }
        listeners.forEach { $0.remove() }; listeners.removeAll()
        let ids = watched; watched.removeAll(); following.removeAll(); followers.removeAll()
        editorialReady = false; publicReady = false; feedReady = false; myPostsReady = false
        status = "Loading community…"; start(name: name, biography: biography)
        ids.forEach { watch($0) }; onChange?()
    }
    func stop() { publicationLoading?.finish(); stopped = true; listeners.forEach { $0.remove() }; listeners.removeAll(); onChange = nil; creators.removeAll(); posts.removeAll(); following.removeAll(); followers.removeAll(); pending.removeAll() }
    deinit { publicationLoading?.finish(); listeners.forEach { $0.remove() } }
}

struct MemberPost: Decodable {
    let id: String
    let authorUID: String
    let authorName: String
    let title: String
    let body: String
    let photoData: Data?
    let visibility: String
    let createdAt: Date
    var presentation: CommunityEditorialPost {
        CommunityEditorialPost(id: id, title: title, imageID: "", category: "Community", summary: String(body.prefix(100)), body: body,
            materials: [], ideas: [], reflection: "", author: authorName, authorUID: authorUID,
            contentType: "member-post", language: "en", photoData: photoData, visibility: visibility, publishedAt: createdAt)
    }
}
enum PublicationError: LocalizedError {
    case invalidContent, unavailable, changed
    var errorDescription: String? {
        switch self {
        case .invalidContent: return "Use a title of 1–120 characters and a story of 1–4000 characters."
        case .unavailable: return "Connect to the internet and sign in to publish."
        case .changed: return "This draft was already published with different content. Start a new draft."
        }
    }
}

// MARK: - Community actions and server-backed inbox
struct InboxItem {
    let id:String, actorUID:String, kind:String, sourcePath:String
    let date:Date
    let read:Bool
}
enum InboxWriter {
    static func write(transaction:Transaction, actor:String, recipient:String, kind:String, sourcePath:String) {
        guard actor != recipient || kind == "challenge" else { return }
        let id = kind + ":" + sourcePath.replacingOccurrences(of:"/",with:"~") + ":" + recipient
        let ref = CommentDatabase.shared.collection("users").document(recipient).collection("inbox").document(id)
        transaction.setData(["actorUID":actor,"recipientUID":recipient,"kind":kind,"sourcePath":sourcePath,"createdAt":FieldValue.serverTimestamp(),"read":false],forDocument:ref)
    }
    static func commentRecipients(_ comment:LocalComment, transaction:Transaction) throws -> Set<String> {
        guard let key = comment.knowledgeID else { return [] }
        var result=Set<String>()
        let parts=key.split(separator:":",maxSplits:1).map(String.init)
        if parts.count == 2, ["member","community"].contains(parts[0]) {
            let post=try transaction.getDocument(CommentDatabase.shared.collection(parts[0] == "member" ? "memberPosts" : "communityPosts").document(parts[1]))
            if let owner=post.data()?["authorUID"] as? String { result.insert(owner) }
        }
        if let parent=comment.parentID {
            let root=try transaction.getDocument(CommentDatabase.shared.collection("knowledge").document(key).collection("comments").document(parent))
            if let owner=root.data()?["authorUID"] as? String { result.insert(owner) }
        }
        return result
    }
}
final class CommunityActions {
    let uid:String
    private let db=CommentDatabase.shared
    private var listeners:[ListenerRegistration]=[]
    private var reactions:[String:ListenerRegistration]=[:]
    private var stopped=false
    private var operationTickets:[String:NetworkLoadingTicket]=[:]
    private(set) var blocked=Set<String>()
    private(set) var blocksReady=false
    private(set) var counts:[String:Int]=[:]
    private(set) var liked=Set<String>()
    private(set) var pending=Set<String>()
    private(set) var inbox:[InboxItem]=[]
    private(set) var reports:[[String:Any]]=[]
    private(set) var joinedChallenge=false
    private(set) var challengeSubmission:[String:Any]?
    private(set) var status="Connecting…"
    var onChange:(()->Void)?
    private var authorized:Bool { !stopped && AccountService.auth.currentUser?.uid == uid }
    init(uid:String) { self.uid=uid }
    private func begin(_ key:String) { operationTickets[key]=NetworkLoading.shared.begin();onChange?() }
    private func finish(_ key:String) { pending.remove(key);operationTickets.removeValue(forKey:key)?.finish();onChange?() }
    func start() {
        guard authorized else { return }
        listeners.forEach{$0.remove()};listeners=[]
        reactions.values.forEach{$0.remove()};reactions=[:];counts=[:];liked=[];blocksReady=false
        listeners.append(db.collection("users").document(uid).collection("blocks").addSnapshotListener(includeMetadataChanges:true) { [weak self] snap,error in
            guard let self,self.authorized else { return }
            if let snap,!snap.metadata.isFromCache { self.blocked=Set(snap.documents.filter{$0.data()["active"] as? Bool == true}.map(\.documentID));self.blocksReady=true }
            if error != nil { self.status="Community actions could not sync. Tap Retry." };self.onChange?()
        })
        listeners.append(db.collection("users").document(uid).collection("inbox").order(by:"createdAt",descending:true).limit(to:100).addSnapshotListener(includeMetadataChanges:true) { [weak self] snap,error in
            guard let self,self.authorized else { return }
            if let snap { self.inbox=snap.documents.compactMap { doc in
                let d=doc.data();guard let actor=d["actorUID"] as? String,let kind=d["kind"] as? String,let source=d["sourcePath"] as? String,let date=(d["createdAt"] as? Timestamp)?.dateValue() else { return nil }
                return InboxItem(id:doc.documentID,actorUID:actor,kind:kind,sourcePath:source,date:date,read:d["read"] as? Bool ?? false)
            }; self.status=snap.metadata.isFromCache ? "Checking connection…" : "" }
            if error != nil { self.status="Notifications could not load. Tap Retry." };self.onChange?()
        })
        listeners.append(db.collection("reports").whereField("reporterUID",isEqualTo:uid).limit(to:50).addSnapshotListener(includeMetadataChanges:true) { [weak self] snap,error in
            guard let self,self.authorized else { return }
            if let snap { self.reports=snap.documents.map { var d=$0.data();d["id"]=$0.documentID;return d } }
            if error != nil { self.status="Requests could not load. Tap Retry." };self.onChange?()
        })
        listeners.append(db.collection("users").document(uid).collection("challenges").document("one-shelf").addSnapshotListener(includeMetadataChanges:true) { [weak self] snap,_ in
            guard let self,self.authorized else { return };self.joinedChallenge=snap?.data()?["joined"] as? Bool ?? false;self.onChange?()
        })
        listeners.append(db.collection("challenges").document("one-shelf").collection("submissions").document(uid).addSnapshotListener(includeMetadataChanges:true) { [weak self] snap,_ in
            guard let self,self.authorized else { return };self.challengeSubmission=snap?.data();self.onChange?()
        })
    }
    func watchReaction(_ path:String) {
        guard authorized,reactions[path] == nil else { return }
        reactions[path]=db.document(path).collection("likes").addSnapshotListener(includeMetadataChanges:true) { [weak self] snap,error in
            guard let self,self.authorized else { return }
            if let snap,!snap.metadata.isFromCache,!snap.metadata.hasPendingWrites {
                self.counts[path]=snap.documents.count
                if snap.documents.contains(where:{$0.documentID == self.uid}) { self.liked.insert(path) } else { self.liked.remove(path) }
            }
            if error != nil { self.status="Likes could not load. Tap Retry." };self.onChange?()
        }
    }
    func toggleLike(_ path:String,completion:@escaping(Bool)->Void) {
        guard authorized,counts[path] != nil,pending.insert(path).inserted else { return }
        let actor=uid,ref=db.document(path).collection("likes").document(uid),target=db.document(path)
        let remove=liked.contains(path);begin(path)
        db.runTransaction({ transaction,errorPointer in
            do {
                let old=try transaction.getDocument(ref)
                let parent=try transaction.getDocument(target)
                guard parent.exists else { throw PublicationError.unavailable }
                if remove { if old.exists { transaction.deleteDocument(ref) } }
                else if !old.exists {
                    transaction.setData(["authorUID":actor,"createdAt":FieldValue.serverTimestamp()],forDocument:ref)
                    if let owner=parent.data()?["authorUID"] as? String { InboxWriter.write(transaction:transaction,actor:actor,recipient:owner,kind:"like",sourcePath:ref.path) }
                }
            } catch { errorPointer?.pointee=error as NSError };return nil
        }) { [weak self] _,error in
            guard let self,self.authorized else { return };self.finish(path);completion(error == nil)
        }
    }
    func setBlocked(_ target:String,active:Bool,completion:@escaping(Bool)->Void) {
        guard authorized,target != uid,blocksReady,pending.insert("block:"+target).inserted else { return }
        begin("block:"+target)
        let ref=db.collection("users").document(uid).collection("blocks").document(target)
        let follow=db.collection("socialFollows").document(uid+":"+target),actor=uid
        db.runTransaction({ transaction,errorPointer in
            do {
                let old=try transaction.getDocument(follow)
                transaction.setData(["uid":actor,"targetUID":target,"active":active,"updatedAt":FieldValue.serverTimestamp()],forDocument:ref)
                if active && old.exists { transaction.deleteDocument(follow) }
            } catch { errorPointer?.pointee=error as NSError };return nil
        }) { [weak self] _,error in
            guard let self,self.authorized else { return };self.finish("block:"+target);completion(error == nil)
        }
    }
    func submitReport(id:String,target:String,reason:String,details:String,appeal:Bool,completion:@escaping(Bool)->Void) {
        guard authorized,pending.insert("report:"+id).inserted else { return }
        begin("report:"+id)
        let actor=uid,ref=db.collection("reports").document(id)
        db.runTransaction({ transaction,errorPointer in
            do {
                let existing=try transaction.getDocument(ref)
                if !existing.exists { transaction.setData(["reporterUID":actor,"targetPath":target,"reason":reason,"details":details,"kind":appeal ? "appeal" : "report","status":"submitted","createdAt":FieldValue.serverTimestamp()],forDocument:ref) }
                else {
                    let data=existing.data() ?? [:]
                    guard data["reporterUID"] as? String == actor, data["targetPath"] as? String == target,
                          data["reason"] as? String == reason, data["details"] as? String == details,
                          data["kind"] as? String == (appeal ? "appeal" : "report") else { throw PublicationError.unavailable }
                }
            } catch { errorPointer?.pointee=error as NSError };return nil
        }) { [weak self] _,error in
            guard let self,self.authorized else { return };self.finish("report:"+id);completion(error == nil)
        }
    }
    func joinChallenge(_ joined:Bool,completion:@escaping(Bool)->Void) {
        guard authorized,pending.insert("challenge-membership").inserted else { return }
        begin("challenge-membership")
        let actor=uid,ref=db.collection("users").document(uid).collection("challenges").document("one-shelf")
        db.runTransaction({ transaction,_ in
            transaction.setData(["uid":actor,"joined":joined,"updatedAt":FieldValue.serverTimestamp()],forDocument:ref);return nil
        }) { [weak self] _,error in
            guard let self,self.authorized else { return };self.finish("challenge-membership");completion(error == nil)
        }
    }
    func submitChallenge(project:MakeProject,caption:String,photo:Data?,withdraw:Bool,completion:@escaping(Bool)->Void) {
        guard authorized,project.isComplete,pending.insert("challenge-submit").inserted else { completion(false);return }
        begin("challenge-submit")
        let actor=uid,ref=db.collection("challenges").document("one-shelf").collection("submissions").document(uid)
        db.runTransaction({ transaction,errorPointer in
            do {
                let old=try transaction.getDocument(ref)
                var fields:[String:Any] = ["uid":actor,"challengeID":"one-shelf","projectID":project.id.uuidString,"title":project.name,"caption":caption,"photo":photo.map{$0 as Any} ?? NSNull(),"status":withdraw ? "withdrawn" : "submitted","createdAt":old.data()?["createdAt"] ?? FieldValue.serverTimestamp(),"updatedAt":FieldValue.serverTimestamp()]
                if withdraw,let existing=old.data() { fields=existing;fields["status"]="withdrawn";fields["updatedAt"]=FieldValue.serverTimestamp() }
                transaction.setData(fields,forDocument:ref)
                InboxWriter.write(transaction:transaction,actor:actor,recipient:actor,kind:"challenge",sourcePath:ref.path)
            } catch { errorPointer?.pointee=error as NSError };return nil
        }) { [weak self] _,error in
            guard let self,self.authorized else { return };self.finish("challenge-submit");completion(error == nil)
        }
    }
    func markRead(_ id:String) { guard authorized else { return };db.collection("users").document(uid).collection("inbox").document(id).updateData(["read":true]) }
    func stop() { operationTickets.values.forEach{$0.finish()};operationTickets=[:];stopped=true;listeners.forEach{$0.remove()};reactions.values.forEach{$0.remove()};listeners=[];reactions=[:];onChange=nil }
    deinit { operationTickets.values.forEach{$0.finish()};listeners.forEach{$0.remove()};reactions.values.forEach{$0.remove()} }
}
