import Foundation

struct MakeProject: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var completedSteps: Int = 0
    var totalSteps: Int = 6
    var space: String?
    var sourcePost: String?
    var notes: String = ""
    var stepTitles: [String]?
    var materials: [String]?
    var checkedMaterials: Set<String>?
    var noteHistory: [String]?
    var isComplete: Bool { completedSteps >= totalSteps }
}
struct LocalComment: Codable, Equatable {
    var knowledgeID: String? = nil
    var authorUID: String? = nil
    var authorName: String? = nil
    var syncState: String? = nil
    var createdAt: Date? = nil
    var id: String
    var parentID: String?
    var replyTo: String?
    var text: String
}
struct PostDraft: Codable, Equatable {
    var publicationID: String? = nil
    var publicationIsPublic: Bool? = nil
    var title: String
    var body: String
    var imageName: String?
}
struct SpaceDetails: Codable, Equatable {
    var plan: [String: Bool]?
    var notes: String = ""
    var beforePhoto: String?
    var afterPhoto: String?
}
struct RoomState: Codable {
    var libraryPending: [String: PendingLibraryItem]?
    var libraryRevisions: [String: String]?
    var libraryMigrationComplete: Bool?
    // Optional additions preserve compatibility with the first local snapshot format.
    var spaceIDs: [String: String]?
    var spacePending: [String: String]?
    var deletedSpaces: [String: String]?
    var spaceDetails: [String: SpaceDetails]?
    var projectPhotos: [String: [String]]?
    var archivedProjects: Set<UUID>?
    var collectionItems: [String: [String]]?
    var profilePendingRevision: String?
    var profileAvatarData: Data?
    var profilePhoto: String?
    var profileUsername: String?
    var profileLocation: String?

    var projects: [MakeProject] = []
    var saved: Set<String> = []
    // Legacy snapshot field only. Online relationships never read or migrate this set.
    var following: Set<String> = []
    var likes: Set<String> = []
    var joined: Set<String> = []
    var commentsFile: String?
    var comments: [String] = []
    var localComments: [LocalComment]?
    var spaces: [String] = ["Reading corner", "Living room"]
    var collections: [String] = ["Cozy corners"]
    var preferences: [String: Bool] = [:]
    var profileName: String = "Member"
    var biography: String = ""
    var draft: PostDraft?
}
enum RoomError: LocalizedError {
    case emptyName, incompleteProject, missingProject, emptyDraft, invalidUsername, profileTooLong
    var errorDescription: String? {
        switch self {
        case .profileTooLong: return "Keep your name under 81 characters, bio under 501, and location under 121."
        case .invalidUsername: return "Use 3–30 letters, numbers, dots or underscores for your username."
        case .emptyName: return "Please enter a name."
        case .incompleteProject: return "Complete all steps before adding this piece to a space."
        case .missingProject: return "This project is no longer available."
        case .emptyDraft: return "Add a title and a story before saving."
        }
    }
}
/// All mutations write a candidate snapshot before replacing in-memory state.
/// A failed disk write never leaves the visible model ahead of persistence.
final class RoomStore {
    private(set) var state: RoomState
    private let url: URL?
    var onSpacesChanged: (() -> Void)?
    var onLibraryChanged: (() -> Void)?
    init(url: URL?) throws {
        self.url = url
        if let url, FileManager.default.fileExists(atPath: url.path) {
            state = try JSONDecoder().decode(RoomState.self, from: Data(contentsOf: url))
        } else { state = RoomState() }
        if let url, let filename = state.commentsFile {
            guard filename == URL(fileURLWithPath: filename).lastPathComponent else { throw CocoaError(.fileReadCorruptFile) }
            let archive = try JSONDecoder().decode(CommentArchive.self, from: Data(contentsOf: url.deletingLastPathComponent().appendingPathComponent(filename)))
            state.comments = archive.legacy
            state.localComments = archive.comments
        }
        if url != nil { try update { _ in } }
    }
    private struct CommentArchive: Codable {
        var schemaVersion = 1
        var legacyKnowledgeID: String? = "woven-reading-corner"
        var legacy: [String]
        var comments: [LocalComment]
    }
    static func isValidUsername(_ value:String)->Bool {
        value.range(of:"^[A-Za-z0-9_][A-Za-z0-9_.]{2,29}$",options:.regularExpression) != nil
    }
    func saveProfile(name:String,username:String,biography:String,location:String) throws {
        let clean=name.trimmingCharacters(in:.whitespacesAndNewlines)
        let handle=username.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !clean.isEmpty else { throw RoomError.emptyName }
        guard clean.count <= 80, biography.count <= 500, location.count <= 120 else { throw RoomError.profileTooLong }
        guard Self.isValidUsername(handle) else { throw RoomError.invalidUsername }
        try update { state in
            state.profilePendingRevision = UUID().uuidString
            state.profileName=clean;state.profileUsername=handle;state.biography=biography
            state.profileLocation=location.trimmingCharacters(in:.whitespacesAndNewlines)
        }
    }
    func update(syncSpaces: Bool = true, syncLibrary: Bool = true, _ mutation: (inout RoomState) throws -> Void) throws {
        var candidate = state
        try mutation(&candidate)
        var spacesChanged = false
        if syncSpaces {
            var ids = candidate.spaceIDs ?? [:], pending = candidate.spacePending ?? [:], deleted = candidate.deletedSpaces ?? [:]
            for name in Set(state.spaces + candidate.spaces) {
                let changed = state.spaces.contains(name) != candidate.spaces.contains(name)
                    || state.spaceDetails?[name] != candidate.spaceDetails?[name]
                    || state.projects.filter { $0.space == name } != candidate.projects.filter { $0.space == name }
                guard changed else { continue }
                let id = ids[name] ?? state.spaceIDs?[name] ?? SpacePersistence.legacyID(name)
                if candidate.spaces.contains(name) { ids[name] = id; deleted.removeValue(forKey: id) }
                else if !candidate.spaces.contains(where: { ids[$0] == id }) { ids.removeValue(forKey: name); deleted[id] = name }
                pending[id] = UUID().uuidString; spacesChanged = true
            }
            candidate.spaceIDs = ids; candidate.spacePending = pending; candidate.deletedSpaces = deleted
        }
        let libraryChanged = syncLibrary ? try LibraryPersistence.queueChanges(from: state, to: &candidate) : false
        if let url {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            // Commit the comment generation before publishing its pointer in state.
            // A crash before the pointer update leaves the previous generation readable.
            let filename = "\(url.deletingPathExtension().lastPathComponent)-comments-\(UUID().uuidString).json"
            let commentsURL = url.deletingLastPathComponent().appendingPathComponent(filename)
            let archive = CommentArchive(legacy: candidate.comments, comments: candidate.localComments ?? [])
            try JSONEncoder().encode(archive).write(to: commentsURL, options: .atomic)
            var snapshot = candidate
            snapshot.commentsFile = filename
            snapshot.comments = []
            snapshot.localComments = nil
            do { try JSONEncoder().encode(snapshot).write(to: url, options: .atomic) }
            catch { try? FileManager.default.removeItem(at: commentsURL); throw error }
            if let previous = state.commentsFile, previous != filename {
                try? FileManager.default.removeItem(at: url.deletingLastPathComponent().appendingPathComponent(previous))
            }
            candidate.commentsFile = filename
        }
        state = candidate
        if spacesChanged { onSpacesChanged?() }
        if libraryChanged { onLibraryChanged?() }
    }
    @discardableResult func createProject(name: String, sourcePost: String?) throws -> UUID {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { throw RoomError.emptyName }
        let project = MakeProject(id: UUID(), name: clean, sourcePost: sourcePost)
        try update { $0.projects.insert(project, at: 0) }
        return project.id
    }
    func advanceProject(_ id: UUID) throws {
        try update { state in
            guard let i = state.projects.firstIndex(where: { $0.id == id }) else { throw RoomError.missingProject }
            state.projects[i].completedSteps = min(state.projects[i].totalSteps, state.projects[i].completedSteps + 1)
        }
    }
    func placeProject(_ id: UUID, in space: String) throws {
        try update { state in
            guard let i = state.projects.firstIndex(where: { $0.id == id }) else { throw RoomError.missingProject }
            guard state.projects[i].isComplete else { throw RoomError.incompleteProject }
            state.projects[i].space = space
            if !state.spaces.contains(space) { state.spaces.append(space) }
        }
    }
    func saveDraft(title: String, body: String, imageName: String?) throws {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw RoomError.emptyDraft }
        let existing = state.draft
        let unchanged = existing?.title == title && existing?.body == body && existing?.imageName == imageName
        try update { $0.draft = PostDraft(publicationID: unchanged ? (existing?.publicationID ?? UUID().uuidString) : UUID().uuidString, publicationIsPublic: unchanged ? existing?.publicationIsPublic : nil, title: title, body: body, imageName: imageName) }
    }
    func toggleSaved(_ id: String) throws { try update { if !$0.saved.insert(id).inserted { $0.saved.remove(id) } } }
    func toggleLike(_ id: String) throws { try update { if !$0.likes.insert(id).inserted { $0.likes.remove(id) } } }
    func setPreference(_ key: String, value: Bool) throws { try update { $0.preferences[key] = value } }
    func saveSpace(originalName: String?, name: String, notes: String) throws {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { throw RoomError.emptyName }
        guard clean.count <= 80, notes.count <= 4000 else { throw SpaceSyncError.tooLarge }
        guard clean == originalName || !state.spaces.contains(clean) else { throw SpaceSyncError.duplicateName }
        try update { state in
            if let old = originalName, old != clean {
                var ids = state.spaceIDs ?? [:]
                ids[clean] = ids.removeValue(forKey: old) ?? SpacePersistence.legacyID(old)
                state.spaceIDs = ids
            }
            var details = state.spaceDetails ?? [:]
            var value = originalName.flatMap { details[$0] } ?? SpaceDetails()
            value.notes = notes
            if let old = originalName, old != clean {
                state.spaces.removeAll { $0 == old }; details.removeValue(forKey: old)
                for i in state.projects.indices where state.projects[i].space == old { state.projects[i].space = clean }
            }
            if !state.spaces.contains(clean) { state.spaces.append(clean) }
            details[clean] = value; state.spaceDetails = details
        }
    }
    func attachPhoto(_ name: String, toProject id: UUID) throws {
        guard state.projects.contains(where: { $0.id == id }) else { throw RoomError.missingProject }
        try update { state in
            var photos = state.projectPhotos ?? [:]
            photos[id.uuidString, default: []].append(name); state.projectPhotos = photos
        }
    }
    func attachPhoto(_ name: String, toSpace space: String, before: Bool) throws {
        try update { state in
            var details = state.spaceDetails ?? [:]
            var value = details[space] ?? SpaceDetails()
            if before { value.beforePhoto = name } else { value.afterPhoto = name }
            details[space] = value; state.spaceDetails = details
        }
    }
    func archiveProject(_ id: UUID) throws {
        guard state.projects.contains(where: { $0.id == id }) else { throw RoomError.missingProject }
        try update { var archived = $0.archivedProjects ?? []; archived.insert(id); $0.archivedProjects = archived }
    }
    func addSavedItem(_ id: String, to collection: String) throws {
        guard !collection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw RoomError.emptyName }
        try update { state in
            state.saved.insert(id)
            if !state.collections.contains(collection) { state.collections.append(collection) }
            var items = state.collectionItems ?? [:]
            if !items[collection, default: []].contains(id) { items[collection, default: []].append(id) }
            state.collectionItems = items
        }
    }
    func removeCollection(_ name: String) throws {
        try update { $0.collections.removeAll { $0 == name }; $0.collectionItems?.removeValue(forKey: name) }
    }
    func removeSpace(_ name: String) throws {
        try update { state in
            state.spaces.removeAll { $0 == name }; state.spaceDetails?.removeValue(forKey: name)
            for i in state.projects.indices where state.projects[i].space == name { state.projects[i].space = nil }
        }
    }

}

extension RoomStore {
    func setSpacePlan(_ name: String, key: String, value: Bool) throws {
        try update { state in
            var details = state.spaceDetails ?? [:], item = details[name] ?? SpaceDetails()
            var plan = item.plan ?? [:]; plan[key] = value; item.plan = plan
            details[name] = item; state.spaceDetails = details
        }
    }
    func prepareSpaceSync(meaningfulOnly: Bool = false) throws {
        try update(syncSpaces: false, syncLibrary: false) { state in
            var ids = state.spaceIDs ?? [:], pending = state.spacePending ?? [:]
            for name in state.spaces where ids[name] == nil {
                if meaningfulOnly && state.spaceDetails?[name] == nil && ["Reading corner", "Living room"].contains(name) && !state.projects.contains(where: { $0.space == name }) { continue }
                let id = SpacePersistence.legacyID(name)
                ids[name] = id; pending[id] = UUID().uuidString
            }
            state.spaceIDs = ids; state.spacePending = pending
        }
    }
    func applyCloudSpace(_ cloud: CloudSpace, id: String) throws {
        guard state.spacePending?[id] == nil else { return }
        let oldName = state.spaceIDs?.first(where: { $0.value == id })?.key
        let pieces = try JSONDecoder().decode([MakeProject].self, from: Data(cloud.piecesJSON.utf8))
        guard cloud.name.count <= 80, cloud.notes.count <= 4000,
              (cloud.beforePhoto?.count ?? 0) <= 196608, (cloud.afterPhoto?.count ?? 0) <= 196608 else { throw SpaceSyncError.tooLarge }
        // Preserve an independently created local space with the same display name.
        if let other = state.spaceIDs?[cloud.name], other != id { throw SpaceSyncError.duplicateName }
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        func savePhoto(_ data: Data?, suffix: String) throws -> String? {
            guard let data else { return nil }
            let filename = "space-\(UUID().uuidString)-\(suffix).jpg"
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: directory.appendingPathComponent(filename), options: .atomic)
            return filename
        }
        // Revision cache avoids rewriting photos on metadata-only snapshots.
        if state.preferences["spaceRevision.\(id).\(cloud.revision)"] == true { return }
        let before = cloud.deleted ? nil : try savePhoto(cloud.beforePhoto, suffix: "before")
        let after = cloud.deleted ? nil : try savePhoto(cloud.afterPhoto, suffix: "after")
        try update(syncSpaces: false, syncLibrary: false) { state in
            var ids = state.spaceIDs ?? [:], details = state.spaceDetails ?? [:]
            let previous = oldName ?? cloud.name
            state.spaces.removeAll { $0 == previous }
            details.removeValue(forKey: previous); ids.removeValue(forKey: previous)
            for i in state.projects.indices where state.libraryMigrationComplete != true && state.projects[i].space == previous { state.projects[i].space = nil }
            if cloud.deleted {
                var deleted = state.deletedSpaces ?? [:]; deleted[id] = cloud.name; state.deletedSpaces = deleted
            } else {
                state.spaces.append(cloud.name); ids[cloud.name] = id
                details[cloud.name] = SpaceDetails(plan: try JSONDecoder().decode([String: Bool].self, from: Data((cloud.planJSON ?? "{}").utf8)), notes: cloud.notes, beforePhoto: before, afterPhoto: after)
                for var piece in pieces where state.libraryMigrationComplete != true {
                    piece.space = cloud.name
                    if let index = state.projects.firstIndex(where: { $0.id == piece.id }) { state.projects[index].space = cloud.name }
                    else { state.projects.append(piece) }
                }
                state.deletedSpaces?.removeValue(forKey: id)
            }
            state.spaceIDs = ids; state.spaceDetails = details
            state.preferences = state.preferences.filter { !$0.key.hasPrefix("spaceRevision.\(id).") }
            state.preferences["spaceRevision.\(id).\(cloud.revision)"] = true
        }
    }
}
