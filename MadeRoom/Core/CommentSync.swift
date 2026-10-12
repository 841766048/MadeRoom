import Foundation
import FirebaseFirestore
import FirebaseAuth
import Network

/// Owns one authenticated user's outbox; listeners exist only while a comment page is visible.
final class CommentSync {
    let uid: String
    private let store: RoomStore
    private let db: Firestore
    private let monitor = NWPathMonitor()
    private var listener: ListenerRegistration?
    private var readLoading: NetworkLoadingTicket?
    private var writeLoading: NetworkLoadingTicket?
    private var pageLoading: NetworkLoadingTicket?
    private var generation = UUID()
    private var isSending = false
    private var stopped = false
    private var networkEnabled = true
    private var older: [LocalComment] = []
    private var lastDocument: DocumentSnapshot?
    private(set) var knowledgeID = "woven-reading-corner"
    private(set) var remote: [LocalComment] = []
    private(set) var status = "Connecting…"
    private(set) var hasMore = false
    var onChange: (() -> Void)?
    init(uid: String, store: RoomStore) {
        self.uid = uid; self.store = store
        db = CommentDatabase.shared
        monitor.pathUpdateHandler = { [weak self] path in
            if path.status == .satisfied { self?.flush() }
        }
        monitor.start(queue: .main)
    }
    deinit { listener?.remove(); monitor.cancel(); readLoading?.finish(); writeLoading?.finish(); pageLoading?.finish() }
    func stop() { writeLoading?.finish(); stopped = true; unlisten(); monitor.cancel(); onChange = nil }
    private var authorized: Bool { !stopped && AccountService.auth.currentUser?.uid == uid }
    private func collection(_ id: String) -> CollectionReference { db.collection("knowledge").document(id).collection("comments") }
    func listen(to id: String) {
        unlisten(); knowledgeID = id; remote = []; older = []; lastDocument = nil; status = "Connecting…"
        let token = generation
        let loading = NetworkLoading.shared.begin(); readLoading = loading
        listener = collection(id).order(by: "createdAt", descending: true).limit(to: 50)
            .addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
                if error != nil || snapshot?.metadata.isFromCache == false { loading.finish() }
                guard let self, self.authorized, self.generation == token else { return }
                guard let snapshot else { self.status = "Could not load comments. Tap Retry."; self.onChange?(); return }
                let latest = snapshot.documents.compactMap(Self.decode)
                let latestIDs = Set(latest.map(\.id))
                self.remote = latest + self.older.filter { !latestIDs.contains($0.id) }
                if self.older.isEmpty {
                    self.lastDocument = snapshot.documents.last
                    self.hasMore = snapshot.documents.count == 50
                }
                self.status = snapshot.metadata.isFromCache ? "Offline cache · checking connection" : "Live comments"
                self.onChange?()
            }
        flush()
    }
    func unlisten() { readLoading?.finish(); pageLoading?.finish(); pageLoading = nil; listener?.remove(); listener = nil; generation = UUID() }
    func loadMore() {
        guard authorized, pageLoading == nil, hasMore, let cursor = lastDocument else { return }
        let token = generation
        let loading = NetworkLoading.shared.begin(); pageLoading = loading
        collection(knowledgeID).order(by: "createdAt", descending: true).start(afterDocument: cursor).limit(to: 50).getDocuments { [weak self] snapshot, error in
            defer { loading.finish() }
            guard let self, self.authorized, token == self.generation else { return }
            self.pageLoading = nil
            guard let snapshot else { self.status = "Could not load older comments. Tap Retry."; self.onChange?(); return }
            self.pageLoading = nil
            let ids = Set(self.remote.map(\.id))
            let page = snapshot.documents.compactMap(Self.decode).filter { !ids.contains($0.id) }
            self.older += page; self.remote += page
            self.lastDocument = snapshot.documents.last; self.hasMore = snapshot.documents.count == 50
            self.onChange?()
        }
    }
    private static func decode(_ doc: DocumentSnapshot) -> LocalComment? {
        guard let data = doc.data(), let text = data["text"] as? String,
              let author = data["authorUID"] as? String, let name = data["authorName"] as? String,
              let knowledge = data["knowledgeID"] as? String else { return nil }
        return LocalComment(knowledgeID: knowledge, authorUID: author, authorName: name,
                            syncState: "synced", createdAt: (data["createdAt"] as? Timestamp)?.dateValue(),
                            id: doc.documentID, parentID: data["parentID"] as? String, replyTo: data["replyTo"] as? String, text: text)
    }
    @discardableResult func post(text: String, name: String, parentID: String?, replyTo: String?) throws -> String {
        guard authorized else { throw NSError(domain: "CommentSync", code: 401, userInfo: [NSLocalizedDescriptionKey: "Sign in before posting a comment."]) }
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean.count <= 2000 else { throw NSError(domain: "CommentSync", code: 400, userInfo: [NSLocalizedDescriptionKey: "Use 1–2,000 characters for your comment."]) }
        let comment = LocalComment(knowledgeID: knowledgeID, authorUID: uid, authorName: String(name.prefix(80)), syncState: "pending", createdAt: Date(), id: UUID().uuidString, parentID: parentID, replyTo: replyTo.map { String($0.prefix(80)) }, text: clean)
        try store.update { $0.localComments = ($0.localComments ?? []) + [comment] }
        onChange?(); flush(); return comment.id
    }
    func retry(_ id: String) {
        guard authorized else { return }
        do {
            try store.update { state in
                if let index = state.localComments?.firstIndex(where: { $0.id == id && $0.authorUID == uid }) { state.localComments?[index].syncState = "pending" }
            }
            flush(); onChange?()
        } catch { status = "Could not save the retry. Try again."; onChange?() }
    }
    #if DEBUG
    func setTestNetworkEnabled(_ enabled: Bool) {
        guard ProcessInfo.processInfo.arguments.contains("--uitesting"), ProcessInfo.processInfo.arguments.contains("--auth-emulator") else { return }
        networkEnabled = enabled
        if enabled { db.enableNetwork { [weak self] _ in self?.flush(); self?.onChange?() } }
        else { db.disableNetwork { [weak self] _ in self?.onChange?() } }
    }
    #endif
    func flush() {
        guard authorized, networkEnabled, !isSending,
              let comment = store.state.localComments?.first(where: { $0.authorUID == uid && $0.syncState == "pending" }),
              let knowledge = comment.knowledgeID else { return }
        isSending = true
        let uid = self.uid
        let ref = collection(knowledge).document(comment.id)
        let data: [String: Any] = ["knowledgeID": knowledge, "authorUID": uid,
            "authorName": comment.authorName ?? "Maker", "text": comment.text,
            "parentID": comment.parentID as Any? ?? NSNull(), "replyTo": comment.replyTo as Any? ?? NSNull(),
            "createdAt": FieldValue.serverTimestamp()]
        let loading = NetworkLoading.shared.begin(); writeLoading = loading
        db.runTransaction({ transaction, errorPointer -> Any? in
            do {
                let existing = try transaction.getDocument(ref)
                if existing.exists {
                    guard existing.data()?["authorUID"] as? String == comment.authorUID,
                          existing.data()?["text"] as? String == comment.text else {
                        throw NSError(domain: "CommentSync", code: 409)
                    }
                    return true
                }
                let recipients = try InboxWriter.commentRecipients(comment, transaction: transaction)
                transaction.setData(data, forDocument: ref)
                for recipient in recipients { InboxWriter.write(transaction: transaction, actor: uid, recipient: recipient, kind: "comment", sourcePath: ref.path) }
                return true
            } catch { errorPointer?.pointee = error as NSError; return nil }
        }) { [weak self] _, error in
            defer { loading.finish() }
            guard let self else { return }; self.isSending = false
            guard self.authorized else { return }
            let code = (error as NSError?)?.code
            let retryLater = [FirestoreErrorCode.unavailable.rawValue, FirestoreErrorCode.deadlineExceeded.rawValue].contains(code ?? -1)
            var persisted = false
            do {
                try self.store.update { state in
                    if let index = state.localComments?.firstIndex(where: { $0.id == comment.id }) {
                        state.localComments?[index].syncState = error == nil ? "synced" : (retryLater ? "pending" : "failed")
                    }
                }
                persisted = true
            } catch { self.status = "Could not save sync status. Retry is safe." }
            self.onChange?()
            if persisted && !retryLater { self.flush() }
        }
    }
}

enum CommentDatabase {
    static let shared: Firestore = {
        let db = Firestore.firestore(app: AccountService.auth.app!)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--auth-emulator") {
            let settings = db.settings
            settings.host = "127.0.0.1:8188"; settings.isSSLEnabled = false
            settings.cacheSettings = MemoryCacheSettings()
            db.settings = settings
        }
        #endif
        return db
    }()
}
