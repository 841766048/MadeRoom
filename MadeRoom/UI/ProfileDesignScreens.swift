import UIKit

/// Content photographs come from board 07; every surrounding element is an authored UIKit view.
extension ScreenViewController {
    private var profileUnit: CGFloat { view.bounds.width / 333 }
    private var profileInk: UIColor { UIColor(red:0.08,green:0.10,blue:0.13,alpha:1) }
    private var profileMuted: UIColor { UIColor(red:0.40,green:0.42,blue:0.47,alpha:1) }
    private func profileText(_ text:String,_ size:CGFloat=14,_ weight:UIFont.Weight = .regular,_ muted:Bool=false)->UILabel {
        RoomUI.label(text,size:size * profileUnit,weight:weight,color:muted ? profileMuted : profileInk)
    }
    private func profileImage(_ asset:String,height:CGFloat?=nil,radius:CGFloat=10)->UIImageView {
        let image=EditorialImageView(asset: asset);image.contentMode = .scaleAspectFill;image.clipsToBounds=true;image.layer.cornerRadius=radius * profileUnit;image.translatesAutoresizingMaskIntoConstraints=false
        if let height {image.heightAnchor.constraint(equalToConstant:height * profileUnit).isActive=true}
        return image
    }
    private func profileInset(_ view:UIView,_ horizontal:CGFloat=16,_ vertical:CGFloat=0)->UIView {
        let wrapper=UIView();view.translatesAutoresizingMaskIntoConstraints=false;wrapper.addSubview(view)
        NSLayoutConstraint.activate([view.leadingAnchor.constraint(equalTo:wrapper.leadingAnchor,constant:horizontal * profileUnit),view.trailingAnchor.constraint(equalTo:wrapper.trailingAnchor,constant:-horizontal * profileUnit),view.topAnchor.constraint(equalTo:wrapper.topAnchor,constant:vertical * profileUnit),view.bottomAnchor.constraint(equalTo:wrapper.bottomAnchor,constant:-vertical * profileUnit)])
        return wrapper
    }
    private func profileButton(_ title:String,background:UIColor = .clear,color:UIColor?=nil,height:CGFloat=44,action:@escaping()->Void)->UIButton {
        var config=UIButton.Configuration.plain();config.title=AppLanguage.text(title);config.baseForegroundColor=color ?? .roomGreen;config.contentInsets = .init(top:8,leading:12,bottom:8,trailing:12)
        let labelSize = 14 * profileUnit
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { var a=$0;a.font = .systemFont(ofSize:labelSize,weight:.semibold);return a }
        let b=UIButton(configuration:config);b.backgroundColor=background;b.layer.cornerRadius=height * profileUnit/2;b.heightAnchor.constraint(greaterThanOrEqualToConstant:max(44,height * profileUnit)).isActive=true;b.addAction(UIAction{_ in action()},for:.touchUpInside);return b
    }
    private func profileSections(_ names:[String],prefix:String,onSelect:@escaping(Int)->Void)->UIView {
        let row=RoomUI.stack(axis:.horizontal,spacing:0 * profileUnit);row.distribution = .fillEqually
        for (i,name) in names.enumerated() {
            let b=profileButton(name,color:i==segment ? .roomGreen : profileMuted){onSelect(i)};b.configuration?.contentInsets = .zero;b.titleLabel?.numberOfLines=1;b.accessibilityIdentifier="\(prefix).\(name)";b.accessibilityTraits=i==segment ? [.button,.selected] : [.button]
            let line=UIView();line.backgroundColor=i==segment ? .roomGreen : .clear;line.layer.cornerRadius=2;line.heightAnchor.constraint(equalToConstant:3 * profileUnit).isActive=true
            let cell=RoomUI.stack([b,profileInset(line,12)],spacing:0 * profileUnit);row.addArrangedSubview(cell)
        }
        return row
    }
    func buildDesignedProfile() {
        body.spacing=0
        let state=coordinator.store.state
        let name=state.profileName
        let bio=state.biography
        let settings=action("","P05",icon:"gearshape");settings.accessibilityLabel=AppLanguage.text("Settings");settings.configuration?.image=UIImage(systemName:"gearshape",withConfiguration:UIImage.SymbolConfiguration(pointSize:20 * profileUnit));settings.configuration?.baseForegroundColor = .label
        let branding = profileText("Made Room",25,.semibold)
        branding.font = UIFont(name: "Georgia", size: 25 * profileUnit) ?? branding.font
        let header=RoomUI.stack([branding,settings],axis:.horizontal);header.alignment = .center
        add(profileInset(header,16));body.setCustomSpacing(10 * profileUnit,after:body.arrangedSubviews.last!)
        let cover=profileImage("profile-cover",height:90,radius:14)
        cover.isAccessibilityElement=true;cover.accessibilityIdentifier="profile.cover"
        cover.accessibilityLabel=AppLanguage.text("A handmade room with plants, books and a reading chair")
        add(profileInset(cover,16));body.setCustomSpacing(12 * profileUnit,after:body.arrangedSubviews.last!)
        let avatar = UIImageView(image: profilePhoto() ?? UIImage(systemName:"person.crop.circle.fill"))
        avatar.contentMode = .scaleAspectFill; avatar.tintColor = .roomGreen; avatar.clipsToBounds = true
        avatar.layer.cornerRadius = 26 * profileUnit; avatar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([avatar.widthAnchor.constraint(equalToConstant:52 * profileUnit),avatar.heightAnchor.constraint(equalTo:avatar.widthAnchor)])
        let edit=profileButton("Edit profile",background:UIColor(red:0.90,green:0.93,blue:0.91,alpha:1),height:34){[weak self] in self?.act("P04")}
        edit.accessibilityIdentifier="action.P01.P04"
        edit.configuration?.contentInsets = .init(top:6,leading:10,bottom:6,trailing:10)
        edit.setContentCompressionResistancePriority(.required,for:.horizontal)
        edit.setContentHuggingPriority(.required,for:.horizontal)
        let title = profileText(name,17,.bold);title.numberOfLines=2
        let biography = profileText(bio,12,.regular,true);biography.numberOfLines=2
        let details=RoomUI.stack(bio.isEmpty ? [title] : [title,biography],spacing:4 * profileUnit)
        let intro=RoomUI.stack([avatar,details,edit],axis:.horizontal,spacing:10 * profileUnit);intro.alignment = .center
        add(profileInset(intro,16));body.setCustomSpacing(8 * profileUnit,after:body.arrangedSubviews.last!)
        if coordinator.profile?.sending == true || coordinator.profile?.status.contains("failed") == true { addProfileSyncStatus() }
        let stats=RoomUI.stack(axis:.horizontal,spacing:0 * profileUnit);stats.distribution = .fillEqually
        let social = coordinator.community
        let owner = social?.uid ?? ""
        let counts = [(String(state.projects.count), "Makes"), (social?.following[owner].map { String($0.count) } ?? "—", "Following"), (social?.followers[owner].map { String($0.count) } ?? "—", "Followers")]
        for (i,pair) in counts.enumerated() {
            let number=profileText(pair.0,18,.bold);number.textAlignment = .center
            let label=profileText(pair.1,12,.regular,true);label.textAlignment = .center
            let content=RoomUI.stack([number,label],spacing:3 * profileUnit)
            let box=profileInset(content,0,8);box.accessibilityLabel="\(pair.0) \(pair.1)"
            if i<2 {let divider=UIView();divider.backgroundColor = .separator;divider.translatesAutoresizingMaskIntoConstraints=false;box.addSubview(divider);NSLayoutConstraint.activate([divider.widthAnchor.constraint(equalToConstant:0.5 * profileUnit),divider.heightAnchor.constraint(equalToConstant:30 * profileUnit),divider.trailingAnchor.constraint(equalTo:box.trailingAnchor),divider.centerYAnchor.constraint(equalTo:box.centerYAnchor)])}
            if i > 0 {
                let hit = UIButton(); hit.translatesAutoresizingMaskIntoConstraints = false; box.addSubview(hit)
                hit.accessibilityIdentifier = "profile.social.\(pair.1)"; hit.accessibilityLabel = "\(pair.0) \(pair.1)"
                NSLayoutConstraint.activate([hit.leadingAnchor.constraint(equalTo: box.leadingAnchor), hit.trailingAnchor.constraint(equalTo: box.trailingAnchor), hit.topAnchor.constraint(equalTo: box.topAnchor), hit.bottomAnchor.constraint(equalTo: box.bottomAnchor)])
                hit.addAction(UIAction { [weak self] _ in self?.coordinator.openConnections(uid: owner, tab: i == 1 ? 1 : 0) }, for: .touchUpInside)
            }
            stats.addArrangedSubview(box)
        }
        add(profileInset(stats,16));body.setCustomSpacing(9 * profileUnit,after:body.arrangedSubviews.last!)
        add(profileInset(profileSections(["Makes","Spaces","Drafts"],prefix:"profile.section"){[weak self] i in self?.segment=i;self?.refresh()},16))
        body.setCustomSpacing(12 * profileUnit,after:body.arrangedSubviews.last!)
        if segment == 0 {
            addProfileGalleryHeading("My makes", identifier: "profile.add.make") { [weak self] in self?.act("M02") }
            if state.projects.isEmpty { add(profileInset(profileText("No makes yet. Start your first project.",14,.regular,true),16,12)) }
            let tiles = state.projects.map { project -> UIView in
                let image = (state.projectPhotos?[project.id.uuidString] ?? []).reversed().lazy.compactMap { self.localPhoto($0) }.first
                let subtitle = project.isComplete ? AppLanguage.text("Finished") : AppLanguage.text("In progress") + " · \(project.completedSteps) / \(project.totalSteps)"
                return profileThumbnail(image: image, title: project.name, subtitle: subtitle, ratio: 1,
                    identifier: "profile.make.\(project.id.uuidString)", coverAsset: profileProjectCover(project), isSpace: false) { [weak self] in self?.coordinator.openProject(project.id) }
            }
            addProfileGallery(tiles)
        } else if segment == 1 {
            addProfileGalleryHeading("Your spaces", identifier: "profile.add.space") { [weak self] in self?.coordinator.createSpace() }
            if state.spaces.isEmpty { add(profileInset(profileText("Create your first space",14,.regular,true),16,12)) }
            let tiles = state.spaces.map { name -> UIView in
                let details = state.spaceDetails?[name]
                let image = localPhoto(details?.afterPhoto) ?? localPhoto(details?.beforePhoto)
                let count = state.projects.filter { $0.space == name }.count
                let subtitle = AppLanguage.text("\(count) handmade pieces") + " · " + AppLanguage.text("Private")
                return profileThumbnail(image: image, title: name, subtitle: subtitle, ratio: 0.75,
                    identifier: "profile.space.\(name)", coverAsset: profileSpaceCover(name), isSpace: true) { [weak self] in self?.coordinator.openSpace(name) }
            }
            addProfileGallery(tiles)
        } else {
            let b=profileButton(state.draft?.title ?? "Create your first draft",background:.white){[weak self] in self?.act("C02")};b.accessibilityIdentifier="profile.newDraft";add(profileInset(b,16,8))
        }
        let links=RoomUI.stack([action("Saved","P02",icon:"bookmark"),action("My posts","@myPosts",icon:"person.text.rectangle"),action("Activity","P03",icon:"bell")],axis:.horizontal);links.distribution = .fillEqually;add(profileInset(links,16,10))
    }
    private func addProfileGalleryHeading(_ title: String, identifier: String, action: @escaping () -> Void) {
        let plus = RoomUI.button("", icon: "plus.circle") { action() }
        plus.accessibilityIdentifier = identifier; plus.accessibilityLabel = AppLanguage.text(title == "My makes" ? "Create a project" : "Create space")
        plus.widthAnchor.constraint(equalToConstant:44).isActive = true
        let row = RoomUI.stack([profileText(title,17,.semibold),plus],axis:.horizontal)
        row.alignment = .center; add(profileInset(row,16))
        body.setCustomSpacing(8 * profileUnit,after:body.arrangedSubviews.last!)
    }
    private func addProfileGallery(_ tiles: [UIView]) {
        let grid = RoomUI.stack(spacing:14 * profileUnit); grid.accessibilityIdentifier = "profile.gallery"
        for offset in stride(from:0,to:tiles.count,by:2) {
            let row = RoomUI.stack(axis:.horizontal,spacing:12 * profileUnit);row.distribution = .fillEqually;row.alignment = .top
            row.addArrangedSubview(tiles[offset])
            row.addArrangedSubview(offset + 1 < tiles.count ? tiles[offset + 1] : UIView())
            grid.addArrangedSubview(row)
        }
        add(profileInset(grid,16))
    }
    func profileProjectCover(_ project: MakeProject) -> String {
        Self.projectCover(project, posts: coordinator.community?.posts ?? [])
    }
    static func projectCover(_ project: MakeProject, posts: [CommunityEditorialPost]) -> String {
        if let source = project.sourcePost, let post = posts.first(where:{ $0.id == source }) { return post.imageID }
        if project.sourcePost == "nora-post" { return "weave" }
        let name = project.name.lowercased()
        for (words, asset) in [(["clay","pottery","ceramic","陶"],"make-clay"),(["pillow","cushion","靠垫","抱枕"],"make-pillow"),(["flower","花"],"make-flowers"),(["basket","篮"],"search-baskets"),(["vase","瓶"],"creator-vase")] {
            if words.contains(where:{name.contains($0)}) { return asset }
        }
        return "make-weave"
    }
    func profileSpaceCover(_ name: String) -> String {
        let text = name.lowercased()
        if ["entry","hall","玄关","入口"].contains(where:{text.contains($0)}) { return "space-entry" }
        if ["living","客厅"].contains(where:{text.contains($0)}) { return "room-hero" }
        return "space-reading"
    }
    private func profileThumbnail(image: UIImage?, title: String, subtitle: String, ratio: CGFloat, identifier: String, coverAsset: String, isSpace: Bool, action: @escaping () -> Void) -> UIView {
        let frame = UIView();frame.backgroundColor = UIColor(red:0.88,green:0.91,blue:0.86,alpha:1)
        frame.layer.cornerRadius = 12 * profileUnit;frame.clipsToBounds = true
        frame.translatesAutoresizingMaskIntoConstraints = false
        frame.heightAnchor.constraint(equalTo:frame.widthAnchor,multiplier:ratio).isActive = true
        let picture: UIImageView
        if let image { picture = UIImageView(image:image) }
        else {
            picture = EditorialImageView(asset:coverAsset, fallbackImage:DesignCatalog.image(isSpace ? "auth-room" : "auth-mug"), showsGlobalLoading:false)
        }
        picture.contentMode = .scaleAspectFill;picture.tintColor = .roomGreen
        picture.translatesAutoresizingMaskIntoConstraints = false;frame.addSubview(picture)
        picture.accessibilityIdentifier = identifier + (image == nil ? ".preview" : ".photo")
        NSLayoutConstraint.activate([picture.leadingAnchor.constraint(equalTo:frame.leadingAnchor),picture.trailingAnchor.constraint(equalTo:frame.trailingAnchor),picture.topAnchor.constraint(equalTo:frame.topAnchor),picture.bottomAnchor.constraint(equalTo:frame.bottomAnchor)])
        if image == nil {
            let badge = RoomUI.label("Illustrative cover",size:10,weight:.medium,color:.roomGreen)
            let background = RoomUI.card(badge,inset:5);background.backgroundColor = UIColor.roomCream.withAlphaComponent(0.94)
            background.layer.cornerRadius = 6;background.translatesAutoresizingMaskIntoConstraints = false;frame.addSubview(background)
            NSLayoutConstraint.activate([background.leadingAnchor.constraint(equalTo:frame.leadingAnchor,constant:8),background.bottomAnchor.constraint(equalTo:frame.bottomAnchor,constant:-8),background.trailingAnchor.constraint(lessThanOrEqualTo:frame.trailingAnchor,constant:-8)])
        }
        let name = profileText(title,14,.semibold);name.numberOfLines = 2
        let caption = profileText(subtitle,11,.regular,true);caption.numberOfLines = 2
        let content = RoomUI.stack([frame,name,caption],spacing:5 * profileUnit)
        content.isUserInteractionEnabled = false;content.translatesAutoresizingMaskIntoConstraints = false
        let button = UIButton(type:.custom);button.addSubview(content)
        button.accessibilityIdentifier = identifier;button.accessibilityLabel = title + ", " + subtitle
        button.accessibilityHint = image == nil ? AppLanguage.text("Illustrative cover. Add your own photo in the details.") : nil
        button.addAction(UIAction { _ in action() },for:.touchUpInside)
        NSLayoutConstraint.activate([content.leadingAnchor.constraint(equalTo:button.leadingAnchor),content.trailingAnchor.constraint(equalTo:button.trailingAnchor),content.topAnchor.constraint(equalTo:button.topAnchor),content.bottomAnchor.constraint(equalTo:button.bottomAnchor)])
        return button
    }
    func buildDesignedSaved() {
        body.spacing=14 * profileUnit;toolbar("",trailing:"ellipsis",action:"@savedMenu")
        add(RoomUI.stack([profileText("Saved",30,.bold),profileText("Ideas for a more you-filled home.",14,.regular,true)],spacing:2 * profileUnit))
        add(profileSections(["All","Tutorials","Spaces","Posts"],prefix:"saved.filter"){[weak self] i in self?.segment=i;self?.refresh()})
        if segment != 1 {add(designedCollection("Reading corner",count:12,hero:"saved-reading",thumbnails:["saved-books","saved-mug","saved-lamp","saved-plant"]))}
        if segment != 2 {add(designedCollection("Weekend makes",count:18,hero:"saved-weekend",thumbnails:["saved-plate","saved-crochet","saved-blue-mug","saved-fabric"]))}
        let create=profileButton("＋  New collection",background:.roomYellow,color:.black,height:48){[weak self] in self?.act("P10")};create.accessibilityIdentifier="action.P02.P10";add(create)
        
        for name in ["All saved"]+coordinator.store.state.collections {
            let count=name=="All saved" ? coordinator.store.state.saved.count : coordinator.store.state.collectionItems?[name]?.count ?? 0
            let b=profileButton("\(name), \(count) items",background:.white){[weak self] in self?.coordinator.openCollection(name)};b.accessibilityIdentifier="saved.local.\(name)";add(b)
        }
    }
    private func designedCollection(_ title:String,count:Int,hero:String,thumbnails:[String])->UIView {
        let image=profileImage(hero,height:118,radius:0)
        let titleLabel=profileText(title,18,.bold);let caption=profileText("\(count) items",14,.regular,true)
        let arrow=UIImageView(image:UIImage(systemName:"chevron.right"));arrow.tintColor=profileMuted;arrow.widthAnchor.constraint(equalToConstant:12 * profileUnit).isActive=true
        let heading=RoomUI.stack([RoomUI.stack([titleLabel,caption],spacing:2 * profileUnit),arrow],axis:.horizontal);heading.alignment = .center
        let headingBox=profileInset(heading,14,8)
        let photos=RoomUI.stack(axis:.horizontal,spacing:6 * profileUnit);photos.distribution = .fillEqually
        for asset in thumbnails {photos.addArrangedSubview(profileImage(asset,height:70,radius:8))}
        let card=RoomUI.stack([image,headingBox,profileInset(photos,9,0)],spacing:0 * profileUnit);let wrapper=profileInset(card,0,0);wrapper.backgroundColor = .white;wrapper.layer.cornerRadius=12;wrapper.clipsToBounds=true
        let hit=UIButton();hit.translatesAutoresizingMaskIntoConstraints=false;wrapper.addSubview(hit);hit.accessibilityIdentifier="saved.collection.\(title)";hit.accessibilityLabel="\(title), \(count) items";hit.addAction(UIAction{[weak self]_ in self?.coordinator.openExampleCollection(title)},for:.touchUpInside)
        NSLayoutConstraint.activate([hit.leadingAnchor.constraint(equalTo:wrapper.leadingAnchor),hit.trailingAnchor.constraint(equalTo:wrapper.trailingAnchor),hit.topAnchor.constraint(equalTo:wrapper.topAnchor),hit.bottomAnchor.constraint(equalTo:wrapper.bottomAnchor)])
        return wrapper
    }
    func buildDesignedActivity() {
        body.spacing=12;toolbar("Activity")
        guard let actions=coordinator.actions else { return }
        if !actions.status.isEmpty { add(profileText(actions.status,14,.regular,true));add(action("Retry","@actionsRetry")) }
        let events=actions.inbox.filter { event in
            let key=event.kind == "follow" ? "New followers" : event.kind == "like" ? "Likes on your content" : event.kind == "challenge" ? "Challenge updates" : "Replies to your posts"
            return coordinator.store.state.preferences[key] != false && !actions.blocked.contains(event.actorUID)
        }
        if events.isEmpty { add(profileText("No notifications yet.",16,.regular,true)) }
        for item in events {
            coordinator.community?.watch(item.actorUID)
            let name=coordinator.community?.creators[item.actorUID]?.displayName ?? "Member"
            let summary=item.kind == "follow" ? "started following you" : item.kind == "like" ? "liked your content" : item.kind == "challenge" ? "Challenge submission updated" : "commented on your content"
            let title=item.kind == "challenge" ? AppLanguage.text(summary) : name + " · " + AppLanguage.text(summary)
            let open=RoomUI.button((item.read ? "" : "• ") + title) { [weak self] in self?.coordinator.openInbox(item) }
            open.titleLabel?.numberOfLines=0;open.accessibilityIdentifier="inbox." + item.id
            add(RoomUI.card(RoomUI.stack([open,RoomUI.label(item.date.formatted(date:.abbreviated,time:.shortened),size:12,color:.secondaryLabel)])))
        }
    }
    func buildDesignedEditProfile() {
        body.spacing=0;toolbar("")
        let state=coordinator.store.state
        add(RoomUI.stack([profileText("Edit profile",30,.bold),profileText("Tell your story, your way.",15,.regular,true)],spacing:2 * profileUnit));body.setCustomSpacing(22 * profileUnit,after:body.arrangedSubviews.last!)
        let portrait=profileImage("profile-edit-avatar",height:146,radius:73);portrait.widthAnchor.constraint(equalToConstant:146 * profileUnit).isActive=true
        if let image=profilePhoto(){portrait.image=image} else { portrait.image=UIImage(systemName:"person.crop.circle.fill");portrait.tintColor = .roomGreen;portrait.contentMode = .scaleAspectFit }
        let picture=UIView();portrait.translatesAutoresizingMaskIntoConstraints=false;picture.addSubview(portrait)
        NSLayoutConstraint.activate([portrait.topAnchor.constraint(equalTo:picture.topAnchor),portrait.bottomAnchor.constraint(equalTo:picture.bottomAnchor),portrait.centerXAnchor.constraint(equalTo:picture.centerXAnchor)])
        let camera=UIButton(type:.system);camera.setImage(UIImage(systemName:"camera",withConfiguration:UIImage.SymbolConfiguration(pointSize:22 * profileUnit)),for:.normal);camera.tintColor = .white;camera.addAction(UIAction{[weak self]_ in self?.coordinator.pickPhoto(context:"P04")},for:.touchUpInside);camera.backgroundColor = .roomGreen;camera.layer.cornerRadius=24 * profileUnit;camera.layer.borderWidth=1.5;camera.layer.borderColor=UIColor.white.cgColor;camera.accessibilityLabel=AppLanguage.text("Change profile photo");camera.translatesAutoresizingMaskIntoConstraints=false;picture.addSubview(camera)
        NSLayoutConstraint.activate([camera.widthAnchor.constraint(equalToConstant:48 * profileUnit),camera.heightAnchor.constraint(equalToConstant:48 * profileUnit),camera.leadingAnchor.constraint(equalTo:portrait.leadingAnchor,constant:98 * profileUnit),camera.topAnchor.constraint(equalTo:portrait.topAnchor,constant:88 * profileUnit)])
        add(picture)
        let change=profileButton("Change photo"){[weak self] in self?.coordinator.pickPhoto(context:"P04")};add(change);body.setCustomSpacing(20 * profileUnit,after:change)
        addProfileSyncStatus()
        designedProfileField("Display name",key:"name",value:state.profileName)
        designedProfileField("Username",key:"username",value:state.profileUsername ?? "member")
        fields["username"]?.autocapitalizationType = .none;fields["username"]?.autocorrectionType = .no
        let valid=profileText("✓  Username format is valid",12);valid.textColor = .roomGreen;valid.accessibilityIdentifier="profile.username.validation";add(valid);body.setCustomSpacing(22 * profileUnit,after:valid)
        fields["username"]?.addAction(UIAction{[weak self,weak valid]_ in guard let self else{return};let ok=RoomStore.isValidUsername(self.fields["username"]?.text ?? "");valid?.text=AppLanguage.text(ok ? "✓  Username format is valid" : "Use 3–30 letters, numbers, dots or underscores for your username.");valid?.textColor=ok ? .roomGreen : .systemRed},for:.editingChanged)
        add(profileText("Bio",15));body.setCustomSpacing(10 * profileUnit,after:body.arrangedSubviews.last!)
        let editor=UITextView();editor.text=state.biography;editor.font = .systemFont(ofSize:15 * profileUnit);editor.textColor=profileMuted;editor.backgroundColor = .white;editor.layer.cornerRadius=10;editor.layer.borderWidth=0.5;editor.layer.borderColor=UIColor(white:0.80,alpha:1).cgColor;editor.textContainerInset = .init(top:12,left:10,bottom:12,right:10);editor.isScrollEnabled=false;editor.heightAnchor.constraint(greaterThanOrEqualToConstant:66).isActive=true;editor.accessibilityIdentifier="input.bio";editor.accessibilityLabel=AppLanguage.text("Bio");editors["bio"]=editor;add(editor);body.setCustomSpacing(22 * profileUnit,after:editor)
        designedProfileField("Location (private, optional)",key:"location",value:state.profileLocation ?? "",placeholder:"San Francisco, CA",icon:"mappin.and.ellipse")
        let save=profileButton("Save changes",background:.roomGreen,color:.white,height:48){[weak self] in self?.act("@profile")};save.accessibilityIdentifier="action.P04.@profile"
        let footer=UIView();footer.backgroundColor = .roomCream;footer.translatesAutoresizingMaskIntoConstraints=false;save.translatesAutoresizingMaskIntoConstraints=false;footer.addSubview(save);view.addSubview(footer);profileFooter=footer
        let bottom=footer.bottomAnchor.constraint(equalTo:view.safeAreaLayoutGuide.bottomAnchor);bottom.priority = .defaultHigh
        NSLayoutConstraint.activate([footer.leadingAnchor.constraint(equalTo:view.leadingAnchor),footer.trailingAnchor.constraint(equalTo:view.trailingAnchor),footer.bottomAnchor.constraint(lessThanOrEqualTo:view.keyboardLayoutGuide.topAnchor),bottom,save.leadingAnchor.constraint(equalTo:footer.leadingAnchor,constant:18 * profileUnit),save.trailingAnchor.constraint(equalTo:footer.trailingAnchor,constant:-18 * profileUnit),save.topAnchor.constraint(equalTo:footer.topAnchor,constant:8),save.bottomAnchor.constraint(equalTo:footer.bottomAnchor,constant:-12)])
        scroll.contentInset.bottom=76 * profileUnit;scroll.verticalScrollIndicatorInsets.bottom=76 * profileUnit
    }
    func updateProfileSyncStatus() {
        let status = coordinator.profile?.status ?? "Loading profile…"
        profileSyncLabel.text = status
        profileSyncRetry.isHidden = !status.contains("Retry") && !status.contains("Waiting")
    }
    private func addProfileSyncStatus() {
        profileSyncLabel = profileText("",12,.regular,true)
        profileSyncLabel.accessibilityIdentifier = "profile.sync.status"
        profileSyncRetry = profileButton("Retry sync") { [weak self] in self?.coordinator.profile?.retry() }
        profileSyncRetry.accessibilityIdentifier = "profile.sync.retry"
        profileSyncRetry.setContentHuggingPriority(.required, for: .horizontal)
        let row = RoomUI.stack([profileSyncLabel,profileSyncRetry],axis:.horizontal,spacing:8)
        row.alignment = .center
        add(profileInset(row,screen.id == "P01" ? 16 : 0,6))
        updateProfileSyncStatus()
    }
    private func designedProfileField(_ title:String,key:String,value:String,placeholder:String="",icon:String?=nil) {
        add(profileText(title,15));body.setCustomSpacing(8 * profileUnit,after:body.arrangedSubviews.last!)
        let field=UITextField();field.text=value;field.placeholder=AppLanguage.text(placeholder);field.font = .systemFont(ofSize:15 * profileUnit);field.textColor=profileInk;field.accessibilityIdentifier="input.\(key)";field.accessibilityLabel=AppLanguage.text(title);field.clearButtonMode = .whileEditing;field.returnKeyType = .done;field.addAction(UIAction{[weak field]_ in field?.resignFirstResponder()},for:.editingDidEndOnExit);fields[key]=field
        let row=RoomUI.stack(axis:.horizontal,spacing:8 * profileUnit)
        if let icon {let mark=UIImageView(image:UIImage(systemName:icon));mark.tintColor=profileMuted;mark.widthAnchor.constraint(equalToConstant:18 * profileUnit).isActive=true;mark.contentMode = .scaleAspectFit;row.addArrangedSubview(mark)}
        row.addArrangedSubview(field)
        let box=profileInset(row,12,0);box.heightAnchor.constraint(equalToConstant:44 * profileUnit).isActive=true;box.backgroundColor = .white;box.layer.cornerRadius=10;box.layer.borderWidth=0.5;box.layer.borderColor=UIColor(white:0.80,alpha:1).cgColor;add(box);body.setCustomSpacing(key=="username" ? 8 : 24,after:box)
    }
    func buildExampleSavedCollection(_ name:String) {
        toolbar("Saved collection");heading(name)
        let assets=name == "Reading corner" ? ["saved-books","saved-mug","saved-lamp","saved-plant"] : ["saved-plate","saved-crochet","saved-blue-mug","saved-fabric"]
        for asset in assets { add(artworkCard(asset,title:asset.replacingOccurrences(of:"saved-",with:"").capitalized,subtitle:"Inspiration",code:"D04")) }
    }

}
