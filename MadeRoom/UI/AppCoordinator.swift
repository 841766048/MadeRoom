import UIKit
import PhotosUI
import FirebaseAuth
import FirebaseFirestore
import CryptoKit

final class AppCoordinator: NSObject, PHPickerViewControllerDelegate {
    private(set) var store: RoomStore
    private weak var window: UIWindow?
    private var authListener: AuthStateDidChangeListenerHandle?
    private var activeUID: String?
    private var isLaunching = false
    private(set) var comments: CommentSync?
    private(set) var profile: ProfileSync?
    private(set) var spacesSync: SpaceSync?
    private(set) var circleMembership: CircleMembershipSync?
    private(set) var community: CommunitySync?
    private(set) var librarySync: LibrarySync?
    private(set) var actions: CommunityActions?
    var reportTargetPath = ""
    var reportTargetUID = ""
    var reportIsAppeal = false
    var selectedCreatorUID = "example-nora"
    var selectedCircleID = "weaving"
    let catalog: DesignCatalog
    let tabs = RoomTabController()
    private var selectedProjectID: UUID?
    private(set) var selectedSpace = "Reading corner"
    var connectionsTab = 0
    var selectedCollection = "All saved"
    var selectedExampleCollection: String?
    var isCreatingSpace = false
    var showingBeforePhoto = false
    private var photoContext = ""
    private(set) var pendingProjectPhoto: String?
    private var pendingSpacePhoto: String?
    private var selectedPhotoName: String?
    var draftMaterials = ["Cotton cord", "Wooden dowel", "Scissors"]
    var draftCheckedMaterials = Set<String>()
    var currentProject: MakeProject? { store.state.projects.first { $0.id == selectedProjectID } ?? store.state.projects.first }
    var navigation: UINavigationController { tabs.selectedViewController as! UINavigationController }
    var top: UIViewController { navigation.topViewController ?? tabs }
    init(store: RoomStore, catalog: DesignCatalog) { self.store = store; self.catalog = catalog; super.init() }

    func updateLanguageContent() {
        let state = store.state
        var values = [state.profileName, state.biography] + state.spaces + state.collections
        for project in state.projects {
            values.append(project.name); values.append(project.notes)
            values.append(contentsOf: project.materials ?? [])
            values.append(contentsOf: project.stepTitles ?? [])
            values.append(contentsOf: project.noteHistory ?? [])
        }
        values += [state.profileUsername, state.profileLocation, state.draft?.title, state.draft?.body].compactMap { $0 }
        AppLanguage.userContent = Set(values.filter { !$0.isEmpty })
    }
    func start(in window: UIWindow) {
        if ProcessInfo.processInfo.arguments.contains("--reset-test-state") { AppLanguage.setChinese(false); AuthConsent.reset() }
        if ProcessInfo.processInfo.arguments.contains("--auth-chinese") { AppLanguage.setChinese(true) }
        if ProcessInfo.processInfo.arguments.contains("--auth-english") { AppLanguage.setChinese(false) }
        self.window = window
        isLaunching = true
        let launch = LaunchAnimationController()
        launch.onFinish = { [weak self] in
            guard let self else { return }
            self.isLaunching = false
            self.applySession(AccountService.auth.currentUser)
        }
        window.rootViewController = launch
        window.makeKeyAndVisible()
        authListener = AccountService.auth.addStateDidChangeListener { [weak self] _, user in
            self?.applySession(user)
        }
    }
    deinit { if let authListener { AccountService.auth.removeStateDidChangeListener(authListener) } }
    private func applySession(_ user: User?) {
        guard !isLaunching else { return }
        guard let window else { return }
        guard let user else {
            actions?.stop();actions=nil;librarySync?.stop();librarySync=nil
            community?.stop(); community = nil; selectedCreatorUID = "example-nora"
            circleMembership?.stop(); circleMembership = nil; selectedCircleID = "weaving"
            spacesSync?.stop(); spacesSync = nil
            profile?.stop(); profile = nil
            comments?.stop(); comments = nil
            activeUID = nil
            selectedProjectID = nil; pendingProjectPhoto = nil; pendingSpacePhoto = nil; selectedPhotoName = nil
            selectedSpace = "Reading corner"; selectedCollection = "All saved"; selectedExampleCollection = nil
            draftMaterials = ["Cotton cord", "Wooden dowel", "Scissors"]; draftCheckedMaterials = []
            tabs.viewControllers = nil
            window.rootViewController = authenticationNavigation()
            return
        }
        guard activeUID != user.uid else { return }
        do {
            let digest = SHA256.hash(data: Data(user.uid.utf8)).map { String(format: "%02x", $0) }.joined()
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            let namespace = ProcessInfo.processInfo.arguments.contains("--auth-emulator") ? "MadeRoomTestUsers" : "MadeRoomUsers"
            store = try RoomStore(url: base.appendingPathComponent(namespace).appendingPathComponent(digest).appendingPathComponent("state.json"))
            actions?.stop();librarySync?.stop()
            community?.stop()
            circleMembership?.stop()
            spacesSync?.stop()
            comments?.stop()
            comments = CommentSync(uid: user.uid, store: store)
            activeUID = user.uid
            buildMainTabs()
            window.rootViewController = tabs
            profile?.stop()
            profile = ProfileSync(uid: user.uid, store: store)
            profile?.onChange = { [weak self] in
                guard let self, self.activeUID == user.uid else { return }
                self.updateLanguageContent()
                if self.profile?.status == "Profile synced" { self.community?.publishProfile(name: self.store.state.profileName, biography: self.store.state.biography) }
                guard let screen = self.top as? ScreenViewController else { return }
                if screen.screen.id == "P01" { screen.refresh() }
                else if screen.screen.id == "P04" { screen.updateProfileSyncStatus() }
            }
            profile?.start()
            librarySync = LibrarySync(uid:user.uid,store:store)
            librarySync?.onChange = { [weak self] in
                guard let self,self.activeUID == user.uid else { return }
                self.syncMakingRoot()
                guard let screen=self.top as? ScreenViewController else { return }
                if ["P01","P02","P05","P06","P07","P09","M01","M03","M05","X10"].contains(screen.screen.id) { screen.refresh() }
            }
            actions = CommunityActions(uid:user.uid)
            actions?.onChange = { [weak self] in
                guard let self,self.activeUID == user.uid,let screen=self.top as? ScreenViewController else { return }
                if screen.screen.id == "C04" { screen.renderCommentFeed() }
                else if ["C01","C03","C05","C06","C09","C11","P03","P06","X09"].contains(screen.screen.id) { screen.refresh() }
            }
            actions?.start()
            spacesSync = SpaceSync(uid: user.uid, store: store)
            spacesSync?.onChange = { [weak self] in
                guard let self, self.activeUID == user.uid else { return }
                if self.spacesSync?.ready == true { self.librarySync?.start() }
                self.updateLanguageContent()
                if !self.store.state.spaces.contains(self.selectedSpace), let first = self.store.state.spaces.first { self.selectedSpace = first }
                guard let screen = self.top as? ScreenViewController else { return }
                if ["S01", "S02", "P01"].contains(screen.screen.id) { screen.refresh() }
                else if screen.screen.id == "S03" { screen.spaceSyncStatus?.text = self.spacesSync?.status }
            }
            spacesSync?.start()
            circleMembership = CircleMembershipSync(uid: user.uid)
            circleMembership?.onChange = { [weak self] in
                guard let self, self.activeUID == user.uid,
                      let screen = self.top as? ScreenViewController, ["C08", "C12"].contains(screen.screen.id) else { return }
                screen.refresh()
            }
            circleMembership?.start()
            community = CommunitySync(uid: user.uid)
            community?.onChange = { [weak self] in
                guard let self, self.activeUID == user.uid, let screen = self.top as? ScreenViewController,
                      ["C01", "C02", "C03", "C05", "C06", "C13", "P01", "P03", "P09", "X05"].contains(screen.screen.id) else { return }
                screen.refresh()
            }
            community?.start(name: store.state.profileName, biography: store.state.biography)
        } catch {
            try? AccountService.auth.signOut()
        }
    }

    /// Builds navigation only. The window is attached exclusively after Firebase authentication.
    func buildMainTabs() {
            updateLanguageContent()
            tabs.viewControllers = zip(ScreenRoutes.roots, ScreenRoutes.tabs).enumerated().map { i, pair in
                let id = pair.0 == "M01" && store.state.projects.isEmpty ? "X02" : pair.0
                let nav = RoomNavigationController(rootViewController: makeScreen(id))
                nav.onNavigationChanged = { [weak self] in self?.tabs.updateBar() }
                nav.tabBarItem = UITabBarItem(title: pair.1, image: RoomTabIcon.image(at: i), selectedImage: RoomTabIcon.image(at: i, selected: true))
                nav.tabBarItem.tag = i
                return nav
            }
            tabs.selectedIndex = 0
            tabs.onSelect = { [weak self] index in self?.selectTab(index) }
            tabs.tabBar.tintColor = .roomGreen
    }

    private func authenticationNavigation() -> UINavigationController {
        let args = ProcessInfo.processInfo.arguments
        let preview = args.firstIndex(of: "--auth-preview").flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil }
        let consent = preview == "privacy" || (preview == nil && !AuthConsent.accepted)
        let login = AuthViewController(page: .login, showConsent: consent)
        let nav = UINavigationController(rootViewController: login)
        if preview == "register" || preview == "reset" {
            nav.setViewControllers([login, AuthViewController(page: preview == "register" ? .register : .reset)], animated: false)
        }
        nav.isModalInPresentation = true
        return nav
    }
    func makeScreen(_ id: String) -> UIViewController {
        guard let screen = catalog[id] else {
            let vc = UIViewController(); vc.view.backgroundColor = .roomCream
            let label = UILabel(frame: CGRect(x: 24, y: 100, width: 330, height: 100)); label.numberOfLines = 0; label.text = AppLanguage.text("This page is unavailable. Please go back."); vc.view.addSubview(label); return vc
        }
        let controller = ScreenViewController(screen: screen, coordinator: self)
        if ["C05", "C06"].contains(id) { controller.creatorUID = selectedCreatorUID; controller.segment = connectionsTab }
        return controller
    }
    /// Tabs retain independent stacks. Selecting an explicit root or reselecting a tab returns to its root.
    func selectTab(_ index: Int, returnToRoot: Bool = false) {
        guard let controllers = tabs.viewControllers, controllers.indices.contains(index) else { return }
        let reselected = tabs.selectedIndex == index
        syncMakingRoot()
        tabs.selectedIndex = index
        if returnToRoot || reselected { navigation.popToRootViewController(animated: false) }
        tabs.updateBar()
    }
    private func syncMakingRoot() {
        guard let nav = tabs.viewControllers?[1] as? UINavigationController else { return }
        let expected = store.state.projects.isEmpty ? "X02" : "M01"
        if (nav.viewControllers.first as? ScreenViewController)?.screen.id != expected {
            var stack = nav.viewControllers
            if stack.isEmpty { stack = [makeScreen(expected)] } else { stack[0] = makeScreen(expected) }
            nav.setViewControllers(stack, animated: false)
        }
    }
    func navigate(_ id: String, preview: Bool = false) {
        guard tabs.viewControllers != nil else { return }
        if ["A01", "A02"].contains(id) { showAuthentication(); return }
        guard catalog[id] != nil else { return }
        if !preview, ["M03","M04","M05","M06","M07"].contains(id), currentProject == nil { navigate("M02"); return }
        if let i = ScreenRoutes.roots.firstIndex(of: id) {
            selectTab(i, returnToRoot: true)
            if preview && id == "M01", (navigation.topViewController as? ScreenViewController)?.screen.id != id {
                navigation.setViewControllers([makeScreen(id)], animated: false)
            }
        } else if let existing = navigation.viewControllers.last(where: { ($0 as? ScreenViewController)?.screen.id == id }) {
            if existing !== navigation.topViewController { navigation.popToViewController(existing, animated: false) }
        } else {
            guard navigation.transitionCoordinator == nil else { return }
            navigation.pushViewController(makeScreen(id), animated: UIView.areAnimationsEnabled && !UIAccessibility.isReduceMotionEnabled)
        }
        tabs.updateBar()
    }
    func openCreator(_ uid: String) {
        selectedCreatorUID = uid; community?.watch(uid); navigate("C05")
        (top as? ScreenViewController)?.creatorUID = uid
        (top as? ScreenViewController)?.refresh()
    }
    func openConnections(uid: String, tab: Int) {
        selectedCreatorUID = uid; connectionsTab = tab; community?.watch(uid); navigate("C06")
        (top as? ScreenViewController)?.creatorUID = uid
        (top as? ScreenViewController)?.segment = tab
        (top as? ScreenViewController)?.refresh()
    }
    func showAuthentication() {
        guard tabs.viewControllers != nil, tabs.presentedViewController == nil else { return }
        let nav = authenticationNavigation()
        nav.modalPresentationStyle = .fullScreen
        tabs.present(nav, animated: false)
    }
    /// Submitted forms and completed steps must not remain reachable through Back.
    private func finishScreen(at id: String) {
        if let existing = navigation.viewControllers.last(where: { ($0 as? ScreenViewController)?.screen.id == id }) {
            navigation.popToViewController(existing, animated: false)
            (existing as? ScreenViewController)?.refresh()
        } else {
            var stack = navigation.viewControllers
            if stack.count > 1 { stack.removeLast() }
            stack.append(makeScreen(id))
            navigation.setViewControllers(stack, animated: false)
        }
        syncMakingRoot(); tabs.updateBar()
    }
    private func closeProjectFlow() {
        let projectRoutes: Set<String> = ["M02","M03","M04","M05","M06","M07","C10","X06","X10","X11"]
        let stack = navigation.viewControllers
        if let start = stack.firstIndex(where: { view in
            guard let screen = view as? ScreenViewController else { return false }
            return projectRoutes.contains(screen.screen.id)
        }), start > 0 {
            navigation.setViewControllers(Array(stack[..<start]), animated: false)
        }
        tabs.updateBar()
    }
    func selectProject(_ id: UUID) { selectedProjectID = id }
    func openProject(_ id: UUID) { selectedProjectID = id; selectedSpace = currentProject?.space ?? store.state.spaces.first ?? "Reading corner"; navigate("M03") }
    func back() {
        guard navigation.viewControllers.count > 1, navigation.transitionCoordinator == nil else { return }
        navigation.popViewController(animated: UIView.areAnimationsEnabled && !UIAccessibility.isReduceMotionEnabled)
        tabs.updateBar()
    }
    private func leaveSelectedCircle() {
        let id = selectedCircleID
        guard let membership = circleMembership, membership.state.ready,
              membership.state.joined.contains(id), !membership.state.pending.contains(id) else { return }
        confirm("Leave this circle?", actionTitle: "Leave circle", body: "Your membership will be removed from your account.") { [weak self, weak membership] in
            membership?.setJoined(false, circleID: id) { [weak self] success in
                guard success, let self, self.selectedCircleID == id,
                      (self.top as? ScreenViewController)?.screen.id == "C12" else { return }
                self.back()
            }
        }
    }
    func perform(_ work: () throws -> Void) { do { try work() } catch { message("Couldn't save", error.localizedDescription) } }
    func message(_ title: String, _ body: String) {
        let alert = RoomDialogController(title: title, message: body, preferredStyle: .alert)
        alert.addAction(RoomDialogAction(title: "OK", style: .default))
        top.present(alert, animated: true)
    }
    func handle(_ action: String, from vc: ScreenViewController, label: String) {
        if action.hasPrefix("@circle.") {
            let id = String(action.dropFirst("@circle.".count))
            guard RoomCircle.all.contains(where: { $0.id == id }) else { return }
            selectedCircleID = id; navigate("C08"); return
        }
        guard action.hasPrefix("@") else {
            if action == "S03" { isCreatingSpace = vc.screen.id == "S01" }
            navigate(action); return
        }
        vc.view.endEditing(true)
        perform {
            switch action {
            case "@back": back()
            case "@createProject":
                let name = vc.input["name"] ?? "My woven wall hanging"
                selectedProjectID = try store.createProject(name: name, sourcePost: vc.editorialPost?.id ?? (vc.screen.id == "C10" ? "nora-post" : nil))
                if let name = pendingProjectPhoto, let id = selectedProjectID { try store.attachPhoto(name, toProject: id); pendingProjectPhoto = nil }
                try store.update { state in
                    if let i = state.projects.firstIndex(where: { $0.id == selectedProjectID }) {
                        state.projects[i].space = selectedSpace; state.projects[i].materials = vc.editorialPost?.materials ?? draftMaterials; state.projects[i].checkedMaterials = vc.editorialPost == nil ? draftCheckedMaterials : []
                        if let post = vc.editorialPost { state.projects[i].stepTitles = post.ideas; state.projects[i].totalSteps = post.ideas.count }
                    }
                }
                draftMaterials = ["Cotton cord", "Wooden dowel", "Scissors"]; draftCheckedMaterials = []
                finishScreen(at: "M03")
            case "@advance":
                guard let project = currentProject else { navigate("M02"); return }
                let index = vc.makingStep ?? min(project.completedSteps, project.totalSteps - 1)
                if index >= project.completedSteps { try store.advanceProject(project.id) }
                if currentProject?.isComplete == true { finishScreen(at: "M05") }
                else { vc.makingStep = min(index + 1, project.totalSteps - 1); vc.refresh() }
            case "@previousStep":
                let index = vc.makingStep ?? min(currentProject?.completedSteps ?? 0, max(0, (currentProject?.totalSteps ?? 6) - 1))
                vc.makingStep = max(0, index - 1); vc.refresh()
            case "@place":
                guard let project = currentProject else { navigate("M02"); return }
                try store.placeProject(project.id, in: selectedSpace)
                closeProjectFlow(); navigate("S01"); navigate("S02"); message("Added to your space", "\(project.name) is now in \(selectedSpace).")
            case "@editProject":
                guard let id = currentProject?.id else { throw RoomError.missingProject }
                let name = vc.input["name"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !name.isEmpty else { throw RoomError.emptyName }
                try store.update { s in if let i = s.projects.firstIndex(where: { $0.id==id }) { s.projects[i].name = name; s.projects[i].space = selectedSpace } }; back()
            case "@saveNote":
                guard let id = currentProject?.id else { throw RoomError.missingProject }
                try store.update { s in if let i = s.projects.firstIndex(where: { $0.id==id }) { let note = (vc.input["note"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    if !note.isEmpty && note != s.projects[i].notes { var history = s.projects[i].noteHistory ?? []; if !s.projects[i].notes.isEmpty { history.insert(s.projects[i].notes, at: 0) }; s.projects[i].noteHistory = history }; s.projects[i].notes = note } }; message("Note saved", "Your note is saved and queued for account sync.")
            case "@note": editText(title: "Project note", value: currentProject?.notes ?? "") { text in
                guard let id = self.currentProject?.id else { return }
                self.perform { try self.store.update { s in if let i = s.projects.firstIndex(where: { $0.id==id }) { s.projects[i].notes = text } } }
            }
            case "@draft", "@publish":
                let existing = store.state.draft
                try store.saveDraft(title: vc.input["title"] ?? existing?.title ?? "", body: vc.input["body"] ?? existing?.body ?? "", imageName: existing?.imageName)
                if action == "@draft" { message("Draft saved", "Your story is saved on this device.") }
                else { publishCurrentDraft(from:vc) }
            case "@myPosts": openMyPosts()
            case "@save": saveToCollection(vc.screen.id)
            case "@like": message("Choose a post", "Open a community post to like it.")
            case "@follow": community?.toggleFollow(selectedCreatorUID)
            case "@following": openConnections(uid: community?.uid ?? "", tab: 1)
            case "@comment": navigate("C04")
            case "@sort": message("Newest first", "Comments are displayed newest first.")
            case "@join":
                if circleMembership?.state.joined.contains(selectedCircleID) == true { leaveSelectedCircle() }
                else { circleMembership?.setJoined(true, circleID: selectedCircleID) }
            case "@circleRetry": circleMembership?.start()
            case "@joinChallenge":
                if actions?.joinedChallenge == true { navigate("C11") }
                else { actions?.joinChallenge(true) { [weak self] success in if success { self?.navigate("C11") } else { self?.onlineFailure() } } }
            case "@leaveChallenge": actions?.joinChallenge(false) { [weak self] success in if !success { self?.onlineFailure() } }
            case "@leave": leaveSelectedCircle()
            case "@submitChallenge", "@withdraw": submitChallenge(from:vc,withdraw:action == "@withdraw")
            case "@report", "@review":
                guard !reportTargetPath.isEmpty else { message("Choose content", "Open the content you want to report.");return }
                let details=vc.input["report"] ?? ""
                guard details.count <= 4000 else { message("Text too long","Use up to 4,000 characters.");return }
                let reason=["Spam","Harassment","Other"][min(2,max(0,vc.segment))]
                let fingerprint=reportTargetPath + reason + details + String(reportIsAppeal)
                if vc.reportFingerprint != fingerprint { vc.reportFingerprint=fingerprint;vc.requestID=UUID().uuidString }
                actions?.submitReport(id:vc.requestID,target:reportTargetPath,reason:reason,details:details,appeal:reportIsAppeal) { [weak self] success in
                    if success { self?.message("Request submitted","Your request is saved online. You can check its status in My requests.") }
                    else { self?.onlineFailure() }
                }
            case "@select", "@interest":
                try store.setPreference(label, value: !(store.state.preferences[label] ?? false)); message("Selection updated", "\(label) \(store.state.preferences[label] == true ? "selected" : "deselected").")
            case "@chooseSpace": chooseSpace()
            case "@saveSpace":
                let name = vc.input["space"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? selectedSpace
                guard !name.isEmpty else { throw RoomError.emptyName }
                try store.saveSpace(originalName: isCreatingSpace ? nil : selectedSpace, name: name, notes: vc.input["spaceNotes"] ?? "")
                if let photo = pendingSpacePhoto { try store.attachPhoto(photo, toSpace: name, before: showingBeforePhoto); pendingSpacePhoto = nil }
                selectedSpace = name; isCreatingSpace = false; finishScreen(at: "S02")
            case "@savePlan": spacesSync?.flush(); message("Plan saved", "Your plan is saved locally and will sync to your account.")
            case "@profile":
                let name = vc.input["name"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !name.isEmpty else { throw RoomError.emptyName }
                try store.saveProfile(name:name,username:vc.input["username"] ?? store.state.profileUsername ?? "maya.makes",biography:vc.input["bio"] ?? "",location:vc.input["location"] ?? store.state.profileLocation ?? "")
                if store.state.profileAvatarData == nil, let filename = store.state.profilePhoto,
                   let image = UIImage(contentsOfFile: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename).path) {
                    let data = try ProfileSync.thumbnail(image)
                    try store.update { $0.profileAvatarData = data }
                }
                profile?.flush(); back()
            case "@collection":
                let name = vc.input["collection"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !name.isEmpty else { throw RoomError.emptyName }
                try store.update { if !$0.collections.contains(name) { $0.collections.append(name) } }; finishScreen(at: "P02")
            case "@us", "@metric": try store.setPreference("metric", value: action == "@metric"); message("Units updated", action == "@metric" ? "Measurements use centimeters." : "Measurements use inches.")
            case "@visibility": chooseVisibility()
            case "@photo": photoContext = vc.screen.id; choosePhoto()
            case "@settings": if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            case "@login", "@email": showAuthentication()
            case "@signOut": try AccountService.auth.signOut()
            case "@deleteAccount": confirm("Delete local data?", body: "This signs you out and clears this account's local data, including unsynced changes. Your online account and cloud data will remain unchanged.") { [weak self] in self?.clearLocalAccountData() }
            case "@archive":
                if let id = currentProject?.id { try store.archiveProject(id); closeProjectFlow(); navigate("M01") }
            case "@deleteProject": confirm("Delete this project?", actionTitle: "Delete project", body: "This removes the project and its notes from your account after synchronization.") { self.perform { if let id = self.currentProject?.id { try self.store.update { $0.projects.removeAll { $0.id==id } } }; self.closeProjectFlow(); self.navigate("M01") } }
            case "@export":
                let data = try JSONEncoder().encode(store.state)
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("Made-Room-data.json")
                try data.write(to: url, options: .atomic); share([url])
            case "@savedMenu":
                let menu=RoomDialogController(title:"Saved",message:nil,preferredStyle:.actionSheet)
                menu.addAction(RoomDialogAction(title:"New collection",style:.default){_ in self.navigate("P10")})
                menu.addAction(RoomDialogAction(title:"All saved items",style:.default){_ in self.openCollection("All saved")})
                menu.addAction(RoomDialogAction(title:"Cancel",style:.cancel));presentSheet(menu)
            case "@postMenu": showContentMenu(from:vc)
            case "@projectMenu":
                let menu = RoomDialogController(title: "Project options", message: nil, preferredStyle: .actionSheet)
                menu.addAction(RoomDialogAction(title: "Edit project", style: .default) { _ in self.navigate("M07") })
                menu.addAction(RoomDialogAction(title: "Archive", style: .default) { _ in self.handle("@archive", from: vc, label: "Archive") })
                menu.addAction(RoomDialogAction(title: "Delete project", style: .destructive) { _ in self.handle("@deleteProject", from: vc, label: "Delete project") })
                menu.addAction(RoomDialogAction(title: "Cancel", style: .cancel)); presentSheet(menu)
            case "@filters":
                let sheet = SearchFilterController(filters: SearchFilters(preferences: store.state.preferences)) { [weak self, weak vc] filters in
                    self?.perform { try self?.store.update { filters.write(to: &$0.preferences) }; vc?.showSearchResults() }
                }
                top.present(sheet, animated: true)
            case "@share": share(["Made Room — a handmade home, one project at a time."])
            case "@block", "@unblock": blockCreator(reportTargetUID.isEmpty ? selectedCreatorUID : reportTargetUID,active:action == "@block")
            case "@retry": navigate("D01")
            case "@localCopy":
                if let p = currentProject { selectedProjectID = try store.createProject(name: p.name + " copy", sourcePost: p.sourcePost) }; navigate("M03")
            case "@cloud", "@syncRetry": librarySync?.retry();spacesSync?.retry()
            case "@actionsRetry": actions?.start()
            case "@materials": message("Materials", "Cotton cord: 60 ft / 18.3 m\nWooden dowel: 12 in / 30.5 cm\nWool yarn\nScissors")
            case "@steps": message("Six steps", "1. Cut your cords\n2. Prepare the dowel\n3. Tie the first row\n4. Add more rows\n5. Trim the fringe\n6. Finish and hang")
            case "@tips": message("A softer finish", "Keep each knot loose enough to adjust. Check the row before tightening, then trim the fringe after hanging.")
            case "@editSteps":
                guard let project = currentProject else { throw RoomError.missingProject }
                let old = project.stepTitles ?? ScreenViewController.steps
                editText(title: "Steps · one per line", value: old.joined(separator: "\n"), multiline: true) { text in
                    let titles = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                    guard !titles.isEmpty else { self.message("Add a step", "A project needs at least one step."); return }
                    self.perform { try self.store.update { state in
                        guard let i = state.projects.firstIndex(where: { $0.id == project.id }) else { return }
                        var preserved = 0
                        for (before, after) in zip(old, titles) { if before != after { break }; preserved += 1 }
                        state.projects[i].completedSteps = min(state.projects[i].completedSteps, preserved)
                        state.projects[i].stepTitles = titles; state.projects[i].totalSteps = titles.count
                    }; vc.refresh() }
                }
            case "@material": editText(title: "Add material", value: "") { value in
                let clean = value.trimmingCharacters(in: .whitespacesAndNewlines); guard !clean.isEmpty else { return }
                self.perform {
                    if vc.screen.id == "M02" { if !self.draftMaterials.contains(clean) { self.draftMaterials.append(clean) } }
                    else if let id = self.currentProject?.id { try self.store.update { state in if let i = state.projects.firstIndex(where: { $0.id == id }) { var values = state.projects[i].materials ?? ["Cotton cord", "Wooden dowel", "Scissors"]; if !values.contains(clean) { values.append(clean) }; state.projects[i].materials = values } } }
                    vc.refresh()
                }
            }
            case "@finished", "@progress": showProjects(completed: action == "@finished")
            case "@before", "@after": showingBeforePhoto = action == "@before"; vc.refresh()
            case "@help": message("Made Room", "Browse ideas, start a make, record your steps and add the finished piece to your space.")
            case "@terms": LegalLinks.open(privacy: false, from: vc)
            case "@privacy": LegalLinks.open(privacy: true, from: vc)
            default: message("Unavailable", "This action is not available. Please return to the previous page.")
            }
        }
    }
    func search(_ query: String, from vc: UIViewController) {
        let known = ["weav","woven","pottery","clay","room","space"]
        if known.contains(where: { query.lowercased().contains($0) }) || query.isEmpty {
            if let search = vc as? ScreenViewController, search.screen.id == "D02" { search.showSearchResults() }
            else { navigate("D02") }
        } else { navigate("X12") }
    }
    private func chooseSpace() {
        let alert = RoomDialogController(title: "Choose a space", message: nil, preferredStyle: .actionSheet)
        for space in store.state.spaces { alert.addAction(RoomDialogAction(title: space, style: .default) { _ in self.selectedSpace = space; (self.top as? ScreenViewController)?.refresh() }) }
        alert.addAction(RoomDialogAction(title: "Cancel", style: .cancel)); presentSheet(alert)
    }
    func openMyPosts() {
        guard let definition = catalog["C01"] else { return }
        let controller = ScreenViewController(screen:definition,coordinator:self)
        controller.showsOwnPosts = true;controller.hidesBottomBarWhenPushed = true
        navigation.pushViewController(controller,animated:false);tabs.updateBar()
    }
    private func publishCurrentDraft(from controller: ScreenViewController) {
        guard let community, let userID = activeUID else { message("Publish failed", "Connect to the internet and sign in to publish.");return }
        guard !community.publishing else { return }
        let isPublic = store.state.preferences["public"] == true
        do {
            try store.update {
                if $0.draft?.publicationIsPublic != isPublic { $0.draft?.publicationID = UUID().uuidString }
                $0.draft?.publicationIsPublic = isPublic
            }
        } catch { message("Publish failed",error.localizedDescription);return }
        guard let draft = store.state.draft else { return }
        community.publish(draft,isPublic:isPublic) { [weak self,weak controller] result in
            guard let self, self.activeUID == userID else { return }
            switch result {
            case .success(let post):
                self.perform { if self.store.state.draft?.publicationID == draft.publicationID { try self.store.update { $0.draft = nil } } }
                self.selectedPhotoName = nil
                if let controller, self.top === controller {
                    self.navigate("C01")
                    (self.top as? ScreenViewController)?.openEditorialPost(post.presentation)
                }
                self.message("Published",isPublic ? "Your post is now available in the community." : "Your post is saved online and visible only to you.")
            case .failure(let error):
                self.message("Publish failed",AppLanguage.text("Your draft is saved. Check your connection and try publishing again.") + "\n" + AppLanguage.text(error.localizedDescription))
            }
        }
    }
    func showMemberPostMenu(_ post: CommunityEditorialPost) {
        let menu = RoomDialogController(title:"Post options",message:nil,preferredStyle:.actionSheet)
        menu.addAction(RoomDialogAction(title:"Save post",style:.default) { [weak self] _ in self?.saveToCollection(post.id) })
        if post.authorUID != activeUID {
            menu.addAction(RoomDialogAction(title:"Report content",style:.default) { [weak self] _ in self?.prepareReport(path:"memberPosts/"+post.id,owner:post.authorUID ?? "") })
            menu.addAction(RoomDialogAction(title:"Block maker",style:.destructive) { [weak self] _ in self?.blockCreator(post.authorUID ?? "",active:true) })
        } else {
            menu.addAction(RoomDialogAction(title:"Request review",style:.default) { [weak self] _ in self?.prepareReport(path:"memberPosts/"+post.id,owner:post.authorUID ?? "",appeal:true) })
        }
        if post.authorUID == activeUID {
            menu.addAction(RoomDialogAction(title:"Delete post",style:.destructive) { [weak self] _ in
                self?.confirm("Delete this post?",actionTitle:"Delete post",body:"This removes the post from your online account and the community.") { [weak self] in
                    self?.community?.deletePost(post.id) { [weak self] success in
                        guard let self else { return }
                        if success { self.back(); (self.top as? ScreenViewController)?.refresh() }
                        else { self.message("Delete failed","Connect to the internet and try again.") }
                    }
                }
            })
        }
        menu.addAction(RoomDialogAction(title:"Cancel",style:.cancel));presentSheet(menu)
    }
    private func chooseVisibility() {
        let alert = RoomDialogController(title: "Visibility", message: "Choose who can see this post online.", preferredStyle: .actionSheet)
        for title in ["Only me", "Public"] { alert.addAction(RoomDialogAction(title: title, style: .default) { _ in self.perform { try self.store.setPreference("public", value: title == "Public"); (self.top as? ScreenViewController)?.refresh() } }) }
        alert.addAction(RoomDialogAction(title: "Cancel", style: .cancel)); presentSheet(alert)
    }
    private func presentSheet(_ sheet: RoomDialogController) {
        sheet.popoverPresentationController?.sourceView = top.view
        sheet.popoverPresentationController?.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 1, height: 1)
        top.present(sheet, animated: true)
    }
    private func confirm(_ title: String, actionTitle: String = "Delete", body: String, completion: @escaping () -> Void) {
        let alert = RoomDialogController(title: title, message: body, preferredStyle: .alert)
        alert.addAction(RoomDialogAction(title: "Cancel", style: .cancel))
        alert.addAction(RoomDialogAction(title: actionTitle, style: .destructive) { _ in completion() }); top.present(alert, animated: true)
    }
    private func editText(title: String, value: String, multiline: Bool = false, save: @escaping (String)->Void) {
        let editor = TextEditorController(title: title, value: value, save: save)
        top.present(UINavigationController(rootViewController: editor), animated: true)
    }
    private func share(_ items: [Any]) {
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        vc.popoverPresentationController?.sourceView = top.view
        top.present(vc, animated: true)
    }
    func choosePhoto() {
        var config = PHPickerConfiguration(photoLibrary: .shared()); config.filter = .images; config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config); picker.delegate = self; top.present(picker, animated: true)
    }
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
        let pickedUID = activeUID
        let pickedContext = photoContext
        provider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
            guard let self else { return }
            guard let image = image as? UIImage, let data = image.jpegData(compressionQuality: 0.85) else {
                DispatchQueue.main.async { self.message("Couldn't load photo", error?.localizedDescription ?? "Please choose another image.") }; return
            }
            DispatchQueue.main.async {
                guard self.activeUID == pickedUID, pickedUID != nil else { return }
                if pickedContext == "P04" {
                    self.perform {
                        let thumbnail = try ProfileSync.thumbnail(image)
                        let draft = (self.top as? ScreenViewController)?.input ?? [:]
                        try self.store.saveProfile(name: draft["name"] ?? self.store.state.profileName,
                            username: draft["username"] ?? self.store.state.profileUsername ?? "maya.makes",
                            biography: draft["bio"] ?? self.store.state.biography,
                            location: draft["location"] ?? self.store.state.profileLocation ?? "")
                        try self.store.update { $0.profileAvatarData = thumbnail; $0.profilePhoto = nil }
                        self.profile?.flush()
                        (self.top as? ScreenViewController)?.refresh()
                    }
                    return
                }
                self.perform {
                    let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    let name = "photo-\(UUID().uuidString).jpg"
                    try data.write(to: directory.appendingPathComponent(name), options: .atomic)
                    if self.photoContext == "M02" { self.pendingProjectPhoto = name }
                    else if ["M04", "M06", "M07"].contains(self.photoContext), let id = self.currentProject?.id {
                        try self.store.attachPhoto(name, toProject: id)
                    } else if ["S02", "S03", "X04"].contains(self.photoContext) {
                        if self.isCreatingSpace { self.pendingSpacePhoto = name }
                        else { try self.store.attachPhoto(name, toSpace: self.selectedSpace, before: self.showingBeforePhoto) }
                    } else if self.photoContext == "P04" {
                        try self.store.update { $0.profilePhoto = name }
                    } else if ["C02", "C13"].contains(pickedContext) {
                        let input = (self.top as? ScreenViewController)?.input ?? [:]
                        let old = self.store.state.draft
                        try self.store.update { $0.draft = PostDraft(publicationID:UUID().uuidString,title:input["title"] ?? old?.title ?? "",body:input["body"] ?? old?.body ?? "",imageName:name) }
                    } else { self.selectedPhotoName = name }
                    (self.top as? ScreenViewController)?.refresh()
                    self.message("Photo saved", "Your photo has been saved on this device.")
                }
            }
        }
    }
    private func showProjects(completed: Bool) {
        let values = store.state.projects.filter { $0.isComplete == completed }
        let alert = RoomDialogController(title: completed ? "Finished makes" : "In progress", message: values.isEmpty ? "No projects here yet." : nil, preferredStyle: .actionSheet)
        for project in values { alert.addAction(RoomDialogAction(title: project.name, style: .default) { _ in self.selectedProjectID = project.id; self.navigate("M03") }) }
        alert.addAction(RoomDialogAction(title: "Cancel", style: .cancel)); presentSheet(alert)
    }
    func openSpace(_ name: String) { selectedSpace = name; showingBeforePhoto = false; navigate("S02") }
    func openCollection(_ name: String) { selectedExampleCollection = nil; selectedCollection = name; navigate("P09") }
    func openExampleCollection(_ name: String) { selectedExampleCollection = name; selectedCollection = name; navigate("P09") }
    func createSpace() { isCreatingSpace = true; navigate("S03") }
    func removeSpace(_ name: String) {
        confirm("Delete this space?", body: "Your projects remain; only their space placement is removed.") {
            self.perform { try self.store.removeSpace(name); (self.top as? ScreenViewController)?.refresh() }
        }
    }
    func removeCollection(_ name: String) {
        confirm("Delete this collection?", body: "Your saved items will remain in All saved.") {
            self.perform { try self.store.removeCollection(name); (self.top as? ScreenViewController)?.refresh() }
        }
    }
    func pickPhoto(context: String) { photoContext = context; choosePhoto() }
    func saveToCollection(_ id: String) {
        let sheet = RoomDialogController(title: "Save to collection", message: nil, preferredStyle: .actionSheet)
        sheet.addAction(RoomDialogAction(title: "All saved", style: .default) { _ in self.perform { try self.store.update { $0.saved.insert(id) } } })
        for name in store.state.collections { sheet.addAction(RoomDialogAction(title: name, style: .default) { _ in self.perform { try self.store.addSavedItem(id, to: name) } }) }
        if store.state.saved.contains(id) { sheet.addAction(RoomDialogAction(title: "Remove from saved", style: .destructive) { _ in self.perform { try self.store.update { state in state.saved.remove(id); for name in state.collectionItems?.keys.map({$0}) ?? [] { state.collectionItems?[name]?.removeAll { $0 == id } } } } }) }
        sheet.addAction(RoomDialogAction(title: "Cancel", style: .cancel)); presentSheet(sheet)
    }
    func showCatalog() {
        let list = CatalogController(screens: catalog.screens) { [weak self] id in self?.tabs.dismiss(animated: true) { self?.navigate(id, preview: true) } }
        top.present(UINavigationController(rootViewController: list), animated: true)
    }
}

extension AppCoordinator {
    func onlineFailure() { message("Could not complete request","Check your connection and try again. Your input has been kept.") }
    func clearLocalAccountData() {
        let local=store
        actions?.stop();librarySync?.stop();community?.stop();comments?.stop();profile?.stop();spacesSync?.stop();circleMembership?.stop()
        perform { try AccountService.auth.signOut();try local.clearLocalCache() }
    }
    func blockCreator(_ uid:String,active:Bool) {
        guard !uid.isEmpty,uid != actions?.uid else { return }
        actions?.setBlocked(uid,active:active) { [weak self] success in
            if success { self?.message(active ? "Creator blocked" : "Creator unblocked",active ? "Their posts and comments are hidden. This setting is saved to your account." : "You can see this creator's content again.") }
            else { self?.onlineFailure() }
        }
    }
    func prepareReport(path:String,owner:String,appeal:Bool=false) {
        reportTargetPath=path;reportTargetUID=owner;reportIsAppeal=appeal;navigate("X01")
    }
    func showContentMenu(from controller:ScreenViewController) {
        if let post=controller.editorialPost,post.isMemberPost { showMemberPostMenu(post);return }
        let post=controller.editorialPost
        let owner=post?.authorUID ?? controller.creatorUID ?? selectedCreatorUID
        let path=post.map { "communityPosts/" + $0.id } ?? "publicProfiles/" + owner
        let menu=RoomDialogController(title:"Content options",message:nil,preferredStyle:.actionSheet)
        if let post { menu.addAction(RoomDialogAction(title:"Save post",style:.default) { [weak self] _ in self?.saveToCollection(post.id) }) }
        menu.addAction(RoomDialogAction(title:"Report content",style:.default) { [weak self] _ in self?.prepareReport(path:path,owner:owner) })
        if owner != actions?.uid {
            let blocked=actions?.blocked.contains(owner) == true
            menu.addAction(RoomDialogAction(title:blocked ? "Unblock creator" : "Block maker",style:.destructive) { [weak self] _ in self?.blockCreator(owner,active:!blocked) })
        }
        menu.addAction(RoomDialogAction(title:"Cancel",style:.cancel));presentSheet(menu)
    }
    func submitChallenge(from controller:ScreenViewController,withdraw:Bool) {
        guard let actions else { onlineFailure();return }
        var project=currentProject
        if withdraw,let submission=actions.challengeSubmission,let raw=submission["projectID"] as? String,let id=UUID(uuidString:raw) {
            project=MakeProject(id:id,name:submission["title"] as? String ?? "Challenge make",completedSteps:1,totalSteps:1)
        }
        guard let project,project.isComplete else { message("Finish your make","Complete a project before submitting it to the challenge.");return }
        let caption=controller.input["caption"] ?? ""
        guard caption.count <= 4000,project.name.count <= 120 else { message("Text too long","Use up to 120 characters for the title and 4,000 for the caption.");return }
        perform {
            let photo=withdraw ? nil : try SpacePersistence.photo(store.state.projectPhotos?[project.id.uuidString]?.last)
            actions.submitChallenge(project:project,caption:caption,photo:photo,withdraw:withdraw) { [weak self] success in
                if success { self?.message(withdraw ? "Submission withdrawn" : "Challenge submitted",withdraw ? "Your online submission has been withdrawn." : "Your challenge submission is saved online.") }
                else { self?.onlineFailure() }
            }
        }
    }
    func openInbox(_ item:InboxItem) {
        actions?.markRead(item.id)
        if item.kind == "follow" { openCreator(item.actorUID);return }
        if item.kind == "challenge" { navigate("C11");return }
        let parts=item.sourcePath.split(separator:"/").map(String.init)
        guard parts.count >= 2 else { return }
        if parts[0] == "knowledge" { openOnlineDiscussion(parts[1]);return }
        if ["communityPosts","memberPosts"].contains(parts[0]) { openOnlineDiscussion((parts[0] == "memberPosts" ? "member:" : "community:") + parts[1]) }
    }
    private func openOnlineDiscussion(_ key:String) {
        let parts=key.split(separator:":",maxSplits:1).map(String.init)
        let isPost=parts.count == 2 && ["community","member"].contains(parts[0])
        let path=isPost ? (parts[0] == "member" ? "memberPosts/" : "communityPosts/") + parts[1] : "knowledge/" + key
        let user=activeUID
        CommentDatabase.shared.document(path).getDocument(source:.server) { [weak self] snapshot,error in
            guard let self,self.activeUID == user else { return }
            guard let snapshot,snapshot.exists,error == nil,let screen=self.catalog["C04"] else { self.message("Unavailable","This post is no longer available.");return }
            let next=ScreenViewController(screen:screen,coordinator:self);next.commentKnowledgeID=key
            if isPost {
                let post=parts[0] == "member" ? (try? snapshot.data(as:MemberPost.self))?.presentation : try? snapshot.data(as:CommunityEditorialPost.self)
                guard let post,!(self.actions?.blocked.contains(post.authorUID ?? "") ?? false) else { self.message("Unavailable","This content is hidden or unavailable.");return }
                next.editorialPost=post;next.commentKnowledgeTitle=post.title
            } else { next.commentKnowledgeTitle=snapshot.data()?["title"] as? String ?? "Comments" }
            self.navigation.pushViewController(next,animated:true)
        }
    }
}
