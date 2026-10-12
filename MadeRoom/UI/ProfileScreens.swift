import UIKit
import FirebaseAuth
extension ScreenViewController {
    func buildProfile() {
        let state=coordinator.store.state
        switch screen.id {
        case "P01": buildDesignedProfile()
        case "P02": buildDesignedSaved()
        case "P03": buildDesignedActivity()
        case "P04": buildDesignedEditProfile()
        case "P05":
            toolbar("Settings");add(languageControl());for (name,icon,target) in [("Account","person.crop.circle","P08"),("Privacy","lock","P06"),("Notifications","bell","P07"),("Units","ruler","P11"),("Accessibility","accessibility","P11"),("Community guidelines","person.2","C12"),("Help","questionmark.circle","@help")]{add(row(name,icon:icon,code:target))};add(row("My requests",icon:"doc.text.magnifyingglass",code:"X09"));add(row("Terms of Service",icon:"doc.text",code:"@terms"));add(row(AuthStyle.text("隐私政策","Privacy policy"),icon:"hand.raised",code:"@privacy"));add(action("Delete local data","@deleteAccount",icon:"trash"))
        case "P06":
            toolbar("Privacy");heading("Your content, your choice.",subtitle:"Choose default visibility for new posts.");toggle("Public posts by default",key:"public");toggle("Private spaces by default",key:"space.private",defaultValue:true);add(RoomUI.label("Your display name and bio are visible to signed-in members. Your email and private location are not shared.",size:15,color:.secondaryLabel))
            add(RoomUI.label("Blocked creators",size:19,weight:.semibold))
            for uid in (coordinator.actions?.blocked ?? []).sorted() {
                coordinator.community?.watch(uid)
                let name=coordinator.community?.creators[uid]?.displayName ?? "Member"
                add(RoomUI.button(name + " · " + AppLanguage.text("Unblock creator")) { [weak self] in self?.coordinator.blockCreator(uid,active:false) })
            }
        case "P07":
            toolbar("Notifications");heading("Keep in touch",subtitle:"Choose the updates you care about.");for name in ["Replies to your posts","New followers","Likes on your content","Challenge updates"]{toggle(name,key:name,defaultValue:true)};add(RoomUI.label("These preferences control in-app notifications and sync to your account.",size:14,color:.secondaryLabel))
        case "P08":
            toolbar("Account");heading(state.profileName,subtitle:AccountService.auth.currentUser?.email ?? "Signed in");add(action("Sign out","@signOut",primary:true));add(row("Edit profile",icon:"pencil",code:"P04"));add(row("Export your data",subtitle:"Download your local projects, notes and preferences.",icon:"square.and.arrow.up",code:"@export"));add(action("Delete local data","@deleteAccount",icon:"trash"))
        case "P09":
            if let example=coordinator.selectedExampleCollection { buildExampleSavedCollection(example);return }
            toolbar("Saved collection");let name=coordinator.selectedCollection;heading(name,subtitle:"Only you can see this collection.")
            let ids=name=="All saved" ? Array(state.saved).sorted() : state.collectionItems?[name] ?? []
            if ids.isEmpty{add(RoomUI.label("Save a tutorial, space or post to keep it here.",size:18,color:.secondaryLabel));add(action("Explore ideas","D01",primary:true))}
            let editorial = (coordinator.community?.posts ?? []) + (coordinator.community?.myPosts.map(\.presentation) ?? [])
            for id in ids {
                if let post = editorial.first(where: { $0.id == id }) { add(editorialCard(post)); continue }
                if let route = coordinator.catalog[id] {
                    add(artworkCard(id.hasPrefix("D") ? "weave" : "reading-room",title:route.name,subtitle:"Saved on this device",code:id))
                } else { add(RoomUI.label(coordinator.community?.feedReady == true ? "This post is no longer available." : "Loading community…",size:15,color:.secondaryLabel)) }
            }
        case "P10":
            toolbar("New collection");heading("Keep your ideas together.");field("Name",key:"collection",placeholder:"e.g. Weekend makes");add(RoomUI.label("Only you can see this collection.",size:14,color:.secondaryLabel));add(action("Create collection","@collection",primary:true));add(action("Cancel","@back"))
        default:
            toolbar("Preferences");heading("Make Made Room work for you.");segments(["US","Metric"],selected:state.preferences["metric"]==true ? 1 : 0){[weak self] i in self?.act(i==1 ? "@metric" : "@us")};add(row("Text size",subtitle:"Uses your device setting.",code:"@settings"));add(row("Reduce motion",subtitle:"Uses your device setting.",code:"@settings"));add(row("Privacy",code:"P06"));add(row("Help",code:"@help"));add(row("Terms of Service",code:"@terms"))
        }
    }
}

extension ScreenViewController {
    func languageControl() -> UIView {
        let selection = UISegmentedControl(items: ["中文", "English"])
        selection.selectedSegmentIndex = AppLanguage.isChinese ? 0 : 1
        selection.accessibilityIdentifier = "settings.language"
        selection.accessibilityLabel = AppLanguage.text("App language")
        selection.heightAnchor.constraint(greaterThanOrEqualToConstant: 40).isActive = true
        selection.addAction(UIAction { [weak self, weak selection] _ in
            guard let self, let selection else { return }
            AppLanguage.setChinese(selection.selectedSegmentIndex == 0)
            self.coordinator.tabs.updateBar()
            self.refresh()
        }, for: .valueChanged)
        return RoomUI.card(RoomUI.stack([RoomUI.label("Language", size: 17, weight: .semibold), selection, RoomUI.label("Choose the language used in the app.", size: 13, color: .secondaryLabel)], spacing: 10))
    }
}
