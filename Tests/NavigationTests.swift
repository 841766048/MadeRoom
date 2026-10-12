import XCTest
import UIKit
@testable import MadeRoom

@MainActor
final class NavigationTests: XCTestCase {
    private var coordinator: AppCoordinator!
    private var window: UIWindow!
    private var directory: URL!
    override func setUpWithError() throws {
        UIView.setAnimationsEnabled(false)
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = try RoomStore(url: directory.appendingPathComponent("state.json"))
        coordinator = AppCoordinator(store: store, catalog: try DesignCatalog())
        window = UIWindow(frame: UIScreen.main.bounds)
        coordinator.buildMainTabs()
        window.rootViewController = coordinator.tabs
        window.makeKeyAndVisible()
    }
    override func tearDownWithError() throws {
        // Drain UIKit's deferred navigation while the screen coordinator is still alive.
        coordinator.tabs.view.layoutIfNeeded()
        for controller in coordinator.tabs.viewControllers ?? [] { controller.view.layoutIfNeeded() }
        CATransaction.flush()
        window.isHidden = true; window.rootViewController = nil; window.windowScene = nil
        window = nil; coordinator = nil
        try? FileManager.default.removeItem(at: directory)
        UIView.setAnimationsEnabled(true)
    }
    private var ids: [String] { coordinator.navigation.viewControllers.compactMap { ($0 as? ScreenViewController)?.screen.id } }
    private var screen: ScreenViewController { let vc=coordinator.top as! ScreenViewController;vc.loadViewIfNeeded();vc.refresh();return vc }
    func testProjectCreationPersistsSpaceAndIndependentMaterials() throws {
        coordinator.draftMaterials = ["Cord", "Dowel"]
        coordinator.draftCheckedMaterials = ["Cord"]
        coordinator.navigate("M02"); let form = screen
        coordinator.handle("@createProject", from: form, label: "Create")
        let first = try XCTUnwrap(coordinator.currentProject)
        XCTAssertEqual(first.space, "Reading corner")
        XCTAssertEqual(first.materials, ["Cord", "Dowel"])
        XCTAssertEqual(first.checkedMaterials, ["Cord"])
        coordinator.navigate("M02"); coordinator.handle("@createProject", from: screen, label: "Create")
        XCTAssertEqual(coordinator.currentProject?.checkedMaterials, [])
        XCTAssertEqual(coordinator.store.state.projects.first(where: { $0.id == first.id })?.checkedMaterials, ["Cord"])
    }
    func testPreviousStepDoesNotChangePersistedCompletion() throws {
        let id = try coordinator.store.createProject(name: "Test weave", sourcePost: nil)
        try coordinator.store.advanceProject(id); try coordinator.store.advanceProject(id)
        coordinator.openProject(id); coordinator.navigate("M04"); let detail = screen
        coordinator.handle("@previousStep", from: detail, label: "Previous")
        XCTAssertEqual(detail.makingStep, 1); XCTAssertEqual(coordinator.currentProject?.completedSteps, 2)
        coordinator.handle("@advance", from: detail, label: "Next")
        XCTAssertEqual(detail.makingStep, 2); XCTAssertEqual(coordinator.currentProject?.completedSteps, 2)
    }
    func testShorteningStepsKeepsOpenGuideIndexInBounds() throws {
        let id = try coordinator.store.createProject(name: "Test weave", sourcePost: nil)
        coordinator.openProject(id); coordinator.navigate("M04"); let detail = screen
        detail.makingStep = 5
        try coordinator.store.update { state in state.projects[0].stepTitles = ["Prepare", "Finish"]; state.projects[0].totalSteps = 2 }
        detail.refresh(); XCTAssertEqual(detail.makingStep, 1)
    }
    func testRepeatedDestinationDoesNotStackDuplicates() {
        coordinator.navigate("D02");coordinator.navigate("D02")
        XCTAssertEqual(ids,["D01","D02"])
        coordinator.navigate("D04");coordinator.navigate("D02")
        XCTAssertEqual(ids,["D01","D02"])
    }
    func testSubmittingSearchKeepsQueryAndOriginalBackDestination() {
        coordinator.navigate("D02");let vc=screen;vc.fields["query"]?.text="weaving"
        coordinator.search("weaving",from:vc)
        XCTAssertEqual(ids,["D01","D02"])
        XCTAssertTrue(coordinator.top === vc)
        XCTAssertEqual(vc.fields["query"]?.text,"weaving")
    }
    func testCreateProjectRemovesSubmittedFormFromBackStack() {
        coordinator.navigate("D04");coordinator.navigate("M02")
        coordinator.handle("@createProject",from:screen,label:"")
        XCTAssertEqual(ids,["D01","D04","M03"])
        coordinator.back();XCTAssertEqual(ids,["D01","D04"])
        coordinator.navigate("M01");XCTAssertEqual(ids,["M01"])
    }
    func testSavingSpaceReturnsToDetailWithoutEditingLoop() {
        coordinator.navigate("S01");coordinator.openSpace("Reading corner");coordinator.navigate("S03")
        let vc=screen;vc.fields["space"]?.text="Quiet corner"
        coordinator.handle("@saveSpace",from:vc,label:"")
        XCTAssertEqual(ids,["S01","S02"])
        coordinator.back();XCTAssertEqual(ids,["S01"])
    }
    func testCreateSpaceReplacesFormAndCollectionSaveReturnsToList() {
        coordinator.navigate("S01");coordinator.createSpace()
        let vc=screen;vc.fields["space"]?.text="Studio"
        coordinator.handle("@saveSpace",from:vc,label:"")
        XCTAssertEqual(ids,["S01","S02"])
        coordinator.navigate("P01");coordinator.navigate("P02");coordinator.navigate("P10")
        let form=screen;form.fields["collection"]?.text="New collection"
        coordinator.handle("@collection",from:form,label:"")
        XCTAssertEqual(ids,["P01","P02"])
    }
    func testPlacementEndsMakingFlowInSpacesTab() throws {
        let id=try coordinator.store.createProject(name:"Test make",sourcePost:nil)
        for _ in 0..<6 { try coordinator.store.advanceProject(id) }
        coordinator.navigate("M01");coordinator.openProject(id);coordinator.navigate("M05")
        coordinator.handle("@place",from:screen,label:"")
        XCTAssertEqual(coordinator.tabs.selectedIndex,2)
        XCTAssertEqual(ids,["S01","S02"])
        let making = coordinator.tabs.viewControllers?[1] as? UINavigationController
        XCTAssertEqual(making?.viewControllers.compactMap { ($0 as? ScreenViewController)?.screen.id },["M01"])
    }
    func testRootBackDoesNotUnexpectedlySwitchTabs() {
        coordinator.navigate("P01");coordinator.back()
        XCTAssertEqual(coordinator.tabs.selectedIndex,4)
    }
    func testTabSelectionRefreshesEmptyMakingRoot() throws {
        _ = try coordinator.store.createProject(name:"A new make",sourcePost:nil)
        coordinator.tabs.onSelect?(1)
        XCTAssertEqual(ids,["M01"])
    }
    func testTabReselectionReturnsToRootAndPreservesOtherStacks() {
        coordinator.navigate("D04")
        coordinator.tabs.onSelect?(4)
        coordinator.navigate("P05")
        coordinator.tabs.onSelect?(0)
        XCTAssertEqual(ids,["D01","D04"])
        coordinator.tabs.onSelect?(0)
        XCTAssertEqual(ids,["D01"])
        coordinator.tabs.onSelect?(4)
        XCTAssertEqual(ids,["P01","P05"])
    }
    func testFormInputSurvivesTemporaryNavigation() {
        coordinator.navigate("C02");let form=screen
        form.fields["title"]?.text="Unsaved title"
        form.editors["body"]?.text="Unsaved body"
        coordinator.navigate("C05");coordinator.back()
        XCTAssertTrue(coordinator.top === form)
        XCTAssertEqual(form.fields["title"]?.text,"Unsaved title")
        XCTAssertEqual(form.editors["body"]?.text,"Unsaved body")
    }

    func testArchivingFromDiscoverDoesNotLeaveStaleProjectStack() throws {
        let id=try coordinator.store.createProject(name:"Archive me",sourcePost:nil)
        coordinator.navigate("D04");coordinator.openProject(id);coordinator.navigate("M07")
        coordinator.handle("@archive",from:screen,label:"")
        XCTAssertEqual(coordinator.tabs.selectedIndex,1)
        coordinator.tabs.onSelect?(0)
        XCTAssertEqual(ids,["D01","D04"])
    }

    func testCommunityEditorialCardsOpenTheirOwnContent() throws {
        let posts = try CommunityEditorialCatalog.load()
        XCTAssertEqual(posts.count, 10)
        XCTAssertEqual(Set(posts.map(\.id)).count, 10)
        coordinator.navigate("C01")
        let feed = screen
        for post in posts {
            feed.openEditorialPost(post)
            let detail = screen
            XCTAssertEqual(detail.editorialPost?.id, post.id)
            func find(_ view: UIView, _ id: String) -> UIView? {
                if view.accessibilityIdentifier == id { return view }
                return view.subviews.compactMap { find($0, id) }.first
            }
            let bar = try XCTUnwrap(find(detail.view, "screen.actions"))
            let tutorial = try XCTUnwrap(find(bar, "action.C03.D04") as? UIButton)
            XCTAssertEqual(tutorial.configuration?.title, AppLanguage.text("View tutorial"))
            for action in ["D04", "C10", "@like", "C04", "@share", "@save"] {
                XCTAssertNotNil(find(detail.view, "action.C03." + action))
            }
            XCTAssertFalse(detail.body.arrangedSubviews.compactMap { $0 as? UILabel }.contains { $0.text == "What to gather" })

            XCTAssertTrue(detail.body.arrangedSubviews.compactMap { $0 as? UILabel }.contains { $0.text == post.title })
            coordinator.back()
            XCTAssertTrue(coordinator.top === feed)
        }
    }

    func testCommunityCommentsUseAnIsolatedDiscussion() throws {
        coordinator.navigate("C01")
        let feed = screen
        let example = try XCTUnwrap(CommunityEditorialCatalog.load().first)
        let member = MemberPost(id: "member-one", authorUID: "owner", authorName: "Maker", title: "My post", body: "My story", photoData: nil, visibility: "public", createdAt: Date()).presentation
        for post in [example, member] {
            feed.openEditorialPost(post)
            XCTAssertTrue(screen.handleEditorialAction("C04"))
            XCTAssertEqual(screen.screen.id, "C04")
            XCTAssertEqual(screen.commentKnowledgeID, (post.isMemberPost ? "member:" : "community:") + post.id)
            XCTAssertEqual(screen.commentKnowledgeTitle, post.title)
            coordinator.back();coordinator.back()
        }
    }

    func testCommunityLayoutAndEditorialActions() async throws {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene { window.windowScene = scene }
        window.overrideUserInterfaceStyle = .light
        window.makeKeyAndVisible()
        let posts = try CommunityEditorialCatalog.load()
        let post = try XCTUnwrap(posts.first)
        coordinator.navigate("C01")
        screen.openEditorialPost(post)
        let detail = screen
        detail.act("@like")
        XCTAssertFalse(coordinator.store.state.likes.contains(post.id), "A like must not be simulated in the local store")
        XCTAssertFalse(coordinator.store.state.likes.contains("C03"))
        detail.act("D04")
        XCTAssertTrue(screen.editorialTutorial)
        XCTAssertEqual(screen.editorialPost?.id, post.id)
        coordinator.back()
        detail.act("C10")
        XCTAssertEqual(screen.fields["name"]?.text, post.title)
        coordinator.handle("@createProject", from: screen, label: "Create project")
        XCTAssertEqual(coordinator.currentProject?.sourcePost, post.id)
        XCTAssertEqual(coordinator.currentProject?.materials, post.materials)
        XCTAssertEqual(coordinator.currentProject?.stepTitles, post.ideas)
        coordinator.navigate("C01")
        screen.openEditorialPost(post)
        try await Task.sleep(nanoseconds: 2_000_000_000)
        window.layoutIfNeeded()
        coordinator.tabs.view.frame = window.bounds
        coordinator.tabs.view.layoutIfNeeded()
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { context in
            window.layer.render(in: context.cgContext)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = "Community-unified-detail"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testProfileThumbnailGridUsesRealPhotosAndRoutes() throws {
        func find(_ view: UIView, _ id: String) -> UIView? {
            if view.accessibilityIdentifier == id { return view }
            return view.subviews.compactMap { find($0,id) }.first
        }
        let image = UIGraphicsImageRenderer(size: CGSize(width:80,height:60)).image { context in
            UIColor.systemGreen.setFill();context.fill(CGRect(x:0,y:0,width:80,height:60))
        }
        let filename = "grid-test-\(UUID().uuidString).jpg"
        let url = FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent(filename)
        try XCTUnwrap(image.jpegData(compressionQuality:0.8)).write(to:url)
        defer { try? FileManager.default.removeItem(at:url) }
        let first = try coordinator.store.createProject(name:"Real photographed make",sourcePost:nil)
        let second = try coordinator.store.createProject(name:"No photo yet",sourcePost:nil)
        _ = try coordinator.store.createProject(name:"Third make",sourcePost:nil)
        try coordinator.store.update {
            $0.projectPhotos = [first.uuidString:[filename,"missing-photo.jpg"]]
            $0.spaceDetails = ["Reading corner":SpaceDetails(beforePhoto:filename)]
        }
        coordinator.navigate("P01");let profile = screen
        for width: CGFloat in [320,402] {
            profile.view.frame = CGRect(x:0,y:0,width:width,height:874);profile.refresh();profile.view.layoutIfNeeded()
            let firstTile = try XCTUnwrap(find(profile.view,"profile.make." + first.uuidString) as? UIButton)
            let secondTile = try XCTUnwrap(find(profile.view,"profile.make." + second.uuidString) as? UIButton)
            let photo = try XCTUnwrap(find(firstTile,"profile.make." + first.uuidString + ".photo"))
            XCTAssertEqual(photo.bounds.width,photo.bounds.height,accuracy:1)
            XCTAssertGreaterThan(photo.bounds.width,100)
            XCTAssertEqual(firstTile.bounds.width,secondTile.bounds.width,accuracy:1)
            let preview = try XCTUnwrap(find(secondTile,"profile.make." + second.uuidString + ".preview") as? UIImageView)
            XCTAssertNotNil(preview.image, "A bundled cover must be visible even before the network image loads")
        }
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene { window.windowScene = scene }
        window.overrideUserInterfaceStyle = .light;window.makeKeyAndVisible();window.layoutIfNeeded()
        func capture(_ name: String) {
            window.layoutIfNeeded()
            let rendered = UIGraphicsImageRenderer(bounds:window.bounds).image { context in window.layer.render(in:context.cgContext) }
            let attachment = XCTAttachment(image:rendered);attachment.name=name;attachment.lifetime = .keepAlways;add(attachment)
        }
        capture("Profile-works-thumbnail-grid")
        let tile = try XCTUnwrap(find(profile.view,"profile.make." + first.uuidString) as? UIButton)
        tile.sendActions(for:.touchUpInside)
        XCTAssertEqual(coordinator.currentProject?.id,first)
        coordinator.navigate("P01");profile.segment=1;profile.refresh();profile.view.layoutIfNeeded()
        let room = try XCTUnwrap(find(profile.view,"profile.space.Reading corner") as? UIButton)
        let photo = try XCTUnwrap(find(room,"profile.space.Reading corner.photo"))
        XCTAssertEqual(photo.bounds.height,photo.bounds.width * 0.75,accuracy:1)
        XCTAssertNotNil(find(profile.view,"profile.space.Living room.preview"))
        capture("Profile-spaces-thumbnail-grid")
        room.sendActions(for:.touchUpInside);XCTAssertEqual(coordinator.selectedSpace,"Reading corner")
        coordinator.navigate("P01");profile.segment=1;profile.refresh()
        (find(profile.view,"profile.add.space") as? UIButton)?.sendActions(for:.touchUpInside)
        XCTAssertTrue(coordinator.isCreatingSpace);XCTAssertEqual(screen.screen.id,"S03")
    }

    func testProfileCoversResolveSourceAndOnlyUseKnownAssets() throws {
        coordinator.navigate("P01");let profile = screen
        let posts = try CommunityEditorialCatalog.load()
        for post in posts {
            let project = MakeProject(id:UUID(),name:"Custom project title",sourcePost:post.id)
            XCTAssertEqual(ScreenViewController.projectCover(project, posts: posts),post.imageID)
        }
        for name in ["Clay bowl","Cushion","Flower arrangement","Basket","Vase","Untitled"] {
            XCTAssertNotNil(TestContent.images[profile.profileProjectCover(MakeProject(id:UUID(),name:name))])
        }
        for name in ["Living room","Entryway","Reading corner","Untitled"] {
            XCTAssertNotNil(TestContent.images[profile.profileSpaceCover(name)])
        }
    }

}
