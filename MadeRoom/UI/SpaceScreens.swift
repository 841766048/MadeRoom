import UIKit
extension ScreenViewController {
    func buildSpaces() {
        let name=coordinator.selectedSpace;let details=coordinator.store.state.spaceDetails?[name]
        let syncLabel = RoomUI.label(coordinator.spacesSync?.status ?? "Loading spaces…",size:12,color:.secondaryLabel)
        syncLabel.accessibilityIdentifier = "spaces.sync.status"; spaceSyncStatus = syncLabel
        let retry = RoomUI.button("Retry sync") { [weak self] in self?.coordinator.spacesSync?.retry() }
        retry.accessibilityIdentifier = "spaces.sync.retry"
        add(RoomUI.stack([syncLabel,retry],axis:.horizontal,spacing:8))
        switch screen.id {
        case "S01":
            let create=RoomUI.button("",icon:"plus"){[weak self] in self?.coordinator.createSpace()};create.accessibilityLabel=AppLanguage.text("Create space");create.accessibilityIdentifier="space.create";create.backgroundColor = .roomYellow;create.layer.cornerRadius=22
            let header=RoomUI.stack([RoomUI.label("Your spaces",size:30,weight:.bold),create],axis:.horizontal);header.alignment = .center;add(header)
            add(RoomUI.label("Collect, style and share the rooms that feel like you.",size:15,color:.secondaryLabel))
            for (i,space) in coordinator.store.state.spaces.enumerated(){
                let cover=RoomUI.image(i%2==0 ? "space-reading" : "space-entry",ratio:0.68);if let im=localPhoto(coordinator.store.state.spaceDetails?[space]?.afterPhoto){cover.image=im}
                let open=RoomUI.button(space){[weak self] in self?.coordinator.openSpace(space)};open.contentHorizontalAlignment = .leading
                let count=coordinator.store.state.projects.filter{$0.space==space}.count
                let more=RoomUI.button("",icon:"ellipsis"){};more.menu=UIMenu(children:[UIAction(title: AppLanguage.text("Delete space"),attributes:.destructive){[weak self]_ in self?.coordinator.removeSpace(space)}]);more.showsMenuAsPrimaryAction=true
                add(RoomUI.card(RoomUI.stack([cover,RoomUI.stack([open,more],axis:.horizontal),RoomUI.label("\(count) handmade pieces",size:13,color:.secondaryLabel)],spacing:5),inset:10))
            }
        case "S02":
            toolbar("Your space");heading(name,subtitle:details?.notes.isEmpty==false ? details?.notes : "A space for your handmade pieces.")
            let image=photo("space-reading",ratio:1);if let chosen=localPhoto(coordinator.showingBeforePhoto ? details?.beforePhoto : details?.afterPhoto){image.image=chosen}
            segments(["Before","After"],selected:coordinator.showingBeforePhoto ? 0 : 1){[weak self] i in guard let self else{return};self.coordinator.showingBeforePhoto=i==0;self.refresh()}
            add(RoomUI.label("Pieces in this space",size:20,weight:.bold))
            let projects=coordinator.store.state.projects.filter{$0.space==name}
            if projects.isEmpty{add(RoomUI.label("Finish a make and add your first piece here.",size:16,color:.secondaryLabel))}
            for p in projects{let b=RoomUI.button(p.name,icon:"leaf"){[weak self] in self?.coordinator.openProject(p.id)};add(RoomUI.card(b))}
            add(RoomUI.stack([action("Edit space","S03",icon:"pencil"),action("Add a piece","S05",icon:"plus")],axis:.horizontal));add(action("Arrange plan","S04"));add(action("Share transformation","C02",primary:true))
        case "S03":
            toolbar(coordinator.isCreatingSpace ? "Create space" : "Edit space");heading("Make this space yours.")
            field("Space name",key:"space",value:coordinator.isCreatingSpace ? "" : name,placeholder:"e.g. Reading corner")
            editor("Notes",key:"spaceNotes",value:coordinator.isCreatingSpace ? "" : details?.notes ?? "")
            segments(["Before photo","After photo"],selected:coordinator.showingBeforePhoto ? 0 : 1){[weak self] i in self?.coordinator.showingBeforePhoto=i==0}
            add(action("Choose a space photo","@photo",icon:"camera"));toggle("Keep this space private",key:"space.private",defaultValue:true);add(action("Save changes","@saveSpace",primary:true))
        case "S04":
            toolbar("Arrange plan");heading("\(name) plan",subtitle:"A cozy, creative spot to slow down.");_=photo("space-reading",ratio:0.70)
            for (item,place) in [("Woven wall hanging","Above the chair"),("Ceramic side table","Next to the chair"),("Linen pillow","On the chair"),("Trailing plant","Top shelf")]{toggle(item,key:"plan.\(item)");add(RoomUI.label(place,size:13,color:.secondaryLabel))};add(action("Save plan","@savePlan",primary:true))
        default:
            toolbar("Add a piece");segments(["My makes","Saved inspiration"],selected:segment){[weak self]_ in self?.refresh()}
            let projects=coordinator.store.state.projects.filter{$0.isComplete}
            if projects.isEmpty{heading("Finish your first piece",subtitle:"Completed projects will appear here.");add(action("Browse tutorials","D04",primary:true))}
            for p in projects{let b=RoomUI.button(p.name,icon:"plus",primary:true){[weak self] in guard let self else{return};self.coordinator.perform{try self.coordinator.store.placeProject(p.id,in:self.coordinator.selectedSpace);self.coordinator.back()}};add(b)}
        }
    }
}
