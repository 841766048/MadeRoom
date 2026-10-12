import UIKit
extension ScreenViewController {
    func buildCommunity() {
        if screen.id == "C03", editorialTutorial, let post = editorialPost { buildEditorialGuide(post); return }
        switch screen.id {
        case "C01":
            if showsOwnPosts {
                toolbar("My posts")
                add(action("Publish","C02",primary:true,icon:"plus"))
                socialStatus()
                if coordinator.community?.myPostsReady == true {
                    let posts = coordinator.community?.myPosts ?? []
                    if posts.isEmpty { add(RoomUI.label("No posts yet.",size:16,color:.secondaryLabel)) }
                    for post in posts { add(editorialCard(post.presentation)) }
                } else { add(RoomUI.label("Loading posts…",size:15,color:.secondaryLabel)) }
                return
            }
            toolbar("Made Room",back:false,trailing:"bell",action:"P03")
            segments(["For you","Following","Circles"], selected: segment) { [weak self] i in
                guard let self else { return }
                if i == 2 { self.coordinator.navigate("C07") } else { self.segment = i; self.refresh() }
            }
            add(RoomUI.stack([action("Publish","C02",primary:true,icon:"plus"),action("My posts","@myPosts",icon:"person.text.rectangle")],axis:.horizontal))
            buildEditorialFeed()
        case "C02","C13":
            toolbar(screen.id=="C02" ? "Publish" : "Edit post");let draft=coordinator.store.state.draft
            let picked = localPhoto(draft?.imageName)
            let cover = UIImageView(image:picked ?? UIImage(systemName:"photo.badge.plus"))
            cover.contentMode = picked == nil ? .center : .scaleAspectFill; cover.tintColor = .roomGreen; cover.backgroundColor = UIColor.roomGreen.withAlphaComponent(0.08)
            cover.clipsToBounds = true;cover.layer.cornerRadius = 14;cover.translatesAutoresizingMaskIntoConstraints = false
            cover.heightAnchor.constraint(equalTo:cover.widthAnchor,multiplier:0.55).isActive = true;add(cover)
            add(action("Add photos","@photo",icon:"photo.badge.plus"));field("Title",key:"title",value:draft?.title ?? "",placeholder:"Give your post a title")
            editor("Caption",key:"body",value:draft?.body ?? "")
            add(row("Visibility",subtitle:coordinator.store.state.preferences["public"] == true ? "Public" : "Only me",icon:"lock",code:"@visibility"))
            add(RoomUI.label(coordinator.store.state.preferences["public"] == true ? "Your post will be visible to signed-in community members." : "Your post will be saved online and visible only to you.",size:13,color:.secondaryLabel))
            let save = action("Save draft","@draft",primary:true);save.isEnabled = coordinator.community?.publishing != true;add(save)
            let publish = action(coordinator.community?.publishing == true ? "Publishing…" : "Publish","@publish");publish.isEnabled = coordinator.community?.publishing != true;add(publish)

        case "C03":
            buildCommunityPost()
        case "C04":
            buildDesignedComments()
        case "C05":
            buildCreatorProfile()
        case "C06":
            buildCreatorConnections()
        case "C07":
            toolbar("Circles");heading("A more creative home together")
            for circle in RoomCircle.all { add(artworkCard(circle.image, title: circle.title, subtitle: circle.summary, code: "@circle." + circle.id)) }
        case "C08":
            let circle = currentCircle
            toolbar(circle.title); _ = photo(circle.image, ratio: 0.49); heading(circle.title, subtitle: circle.summary)
            addCircleMembershipControls()
            add(action("Circle guidelines", "C12"))
            add(artworkCard("challenge-shelf", title: "One shelf, handmade", subtitle: "This month's creative challenge", code: "C09"))
            add(action("Share a make", "C02", icon: "plus"))
        case "C09":
            toolbar("Challenge");heading("One shelf, handmade",subtitle:"Style a shelf with something you made.");_=photo("challenge-shelf",ratio:0.78)
            add(RoomUI.label("Create a handmade piece and style it on a shelf in your home. Pottery, a weave, a candle — anything you make.",size:16))
            for (title,copy) in [("Make one piece","Create something with your hands."),("Style your shelf","Place it on a shelf in your home."),("Share your result","Post a photo and tell us about it.")]{add(RoomUI.card(RoomUI.stack([RoomUI.label(title,size:17,weight:.semibold),RoomUI.label(copy,size:14,color:.secondaryLabel)])))}
            add(action(coordinator.actions?.joinedChallenge == true ? "Continue challenge" : "Join challenge","@joinChallenge",primary:true));add(action("Submit your make","C11"))
            if coordinator.actions?.joinedChallenge == true { add(action("Leave challenge","@leaveChallenge")) }
        case "C10":
            toolbar("Make it your own");_=photo(editorialPost?.imageID ?? "weave",ratio:0.65);heading("Make it your own",subtitle:"Turn inspiration into something made by you.")
            field("Project title",key:"name",value:editorialPost?.title ?? "My woven wall hanging");add(row(coordinator.selectedSpace,subtitle:"Choose a space",code:"@chooseSpace"));add(row("One shelf, handmade",subtitle:"Optional challenge",code:"C09"));add(action("Create project","@createProject",primary:true))
        case "C11":
            toolbar("Submit your make");heading("One shelf, handmade",subtitle:"Share your completed project to this challenge.");add(row(coordinator.currentProject?.name ?? "Choose a completed project",subtitle:"Selected project",code:"M01"));editor("Add a short caption",key:"caption");add(action("Submit to challenge","@submitChallenge",primary:true))
            if let submission=coordinator.actions?.challengeSubmission {
                add(RoomUI.label(AppLanguage.text("Submission status") + ": " + AppLanguage.text(submission["status"] as? String ?? "submitted"),size:15,color:.secondaryLabel))
                if submission["status"] as? String == "submitted" { add(action("Withdraw submission","@withdraw")) }
            }
            if coordinator.actions?.joinedChallenge != true { add(action("Join challenge","@joinChallenge")) }
        default:
            toolbar(currentCircle.title);heading(currentCircle.summary);for (title,copy) in [("Share your own work","Post photos of projects you've made yourself."),("Credit your inspiration","Give your inspiration a shout-out."),("Be kind and specific","Share thoughtful, encouraging feedback."),("Keep advice safe","Choose materials and techniques appropriate to your experience.")]{add(RoomUI.stack([RoomUI.label(title,size:18,weight:.semibold),RoomUI.label(copy,size:15,color:.secondaryLabel)]))};addCircleMembershipControls(guidelines: true)
        }
    }
    var currentCircle: RoomCircle { RoomCircle.all.first { $0.id == coordinator.selectedCircleID } ?? RoomCircle.all[2] }
    func addCircleMembershipControls(guidelines: Bool = false) {
        guard let membership = coordinator.circleMembership else {
            add(RoomUI.label(AuthStyle.text("登录后可管理圈子成员资格。", "Sign in to manage circle membership."), size: 14, color: .secondaryLabel)); return
        }
        let id = currentCircle.id
        let joined = membership.state.joined.contains(id)
        let pending = membership.state.pending.contains(id)
        let title = pending ? AuthStyle.text("正在更新…", "Updating…") : (guidelines ? "Leave circle" : (joined ? "Joined" : "Join circle"))
        let button = action(title, guidelines ? "@leave" : "@join", primary: !guidelines)
        button.isEnabled = membership.state.ready && !pending && (!guidelines || joined)
        add(button)
        let status = RoomUI.label(membership.status, size: 13, color: .secondaryLabel)
        status.accessibilityIdentifier = "circle.membership.status"; add(status)
        if !pending { add(action("Retry", "@circleRetry")) }
    }
    func makerRow(_ name:String,subtitle:String,asset:String="maker")->UIView {
        let image=RoomUI.image(asset,ratio:1,radius:23);image.widthAnchor.constraint(equalToConstant:46).isActive=true
        let text=RoomUI.stack([RoomUI.label(name,size:15,weight:.semibold),RoomUI.label(subtitle,size:12,color:.secondaryLabel)],spacing:4)
        let row=RoomUI.stack([image,text],axis:.horizontal);row.alignment = .center;return row
    }
}


struct CommunityEditorialPost: Decodable {
    let id: String
    let title: String
    let imageID: String
    let category: String
    let summary: String
    let body: String
    let materials: [String]
    let ideas: [String]
    let reflection: String
    let author: String
    let authorUID: String?
    let contentType: String
    let language: String
    var photoData: Data? = nil
    var visibility: String? = nil
    var publishedAt: Date? = nil
    var isMemberPost: Bool { contentType == "member-post" }
}

extension ScreenViewController {
    func buildEditorialFeed() {
        guard let social = coordinator.community else { return }
        socialStatus()
        guard social.feedReady else { return }
        if segment == 1 && social.following[social.uid] == nil { add(RoomUI.label("Loading relationships…", size: 15)); return }
        let visible = social.posts.filter { coordinator.actions?.blocked.contains($0.authorUID ?? "") != true }
        let posts = segment == 1 ? visible.filter { social.following[social.uid]?.contains($0.authorUID ?? "") == true } : visible
        if posts.isEmpty { add(RoomUI.label(segment == 1 ? "Follow a creator to see their posts here." : "No community posts yet.", size: 16, color: .secondaryLabel)) }
        for post in posts { add(editorialCard(post)) }
        if segment == 0 {
            add(RoomUI.label("Meet the creators", size: 22, weight: .bold))
            for person in social.creators.values.filter({ $0.isExample && coordinator.actions?.blocked.contains($0.uid) != true }).sorted(by: { $0.uid < $1.uid }) { addCreatorRow(person.uid) }
        }
    }

    func openEditorialPost(_ post: CommunityEditorialPost) {
        guard let screen = coordinator.catalog["C03"] else { return }
        let detail = ScreenViewController(screen: screen, coordinator: coordinator)
        detail.editorialPost = post
        navigationController?.pushViewController(detail, animated: UIView.areAnimationsEnabled && !UIAccessibility.isReduceMotionEnabled)
    }

    func communityCover(_ post: CommunityEditorialPost, ratio: CGFloat) -> UIImageView {
        if !post.isMemberPost { return RoomUI.image(post.imageID,ratio:ratio,radius:14) }
        let photo = post.photoData.flatMap { UIImage(data:$0) }
        let image = UIImageView(image:photo ?? UIImage(systemName:"text.bubble"))
        image.contentMode = photo == nil ? .center : .scaleAspectFill;image.tintColor = .roomGreen
        image.backgroundColor = UIColor.roomGreen.withAlphaComponent(0.08);image.clipsToBounds = true;image.layer.cornerRadius = 14
        image.translatesAutoresizingMaskIntoConstraints = false;image.heightAnchor.constraint(equalTo:image.widthAnchor,multiplier:ratio).isActive = true
        return image
    }
    func editorialCard(_ post: CommunityEditorialPost) -> UIView {
        let cover = communityCover(post, ratio: 0.63)
        let open = RoomUI.button(post.title) { [weak self] in self?.openEditorialPost(post) }
        open.contentHorizontalAlignment = .leading
        open.titleLabel?.numberOfLines = 0
        open.accessibilityIdentifier = "community.post.\(post.id)"
        return RoomUI.card(RoomUI.stack([cover, open,
            RoomUI.label(post.author + (post.isMemberPost ? " · " + AppLanguage.text(post.visibility == "private" ? "Only me" : "Public") : ""), size: 13, color: .secondaryLabel),
            RoomUI.label(post.summary, size: 13, color: .secondaryLabel)
        ], spacing: 6), inset: 10)
    }

    /// All community posts share the approved C03 composition.
    func buildCommunityPost() {
        let post = editorialPost
        toolbar("Made Room", trailing: "ellipsis", action: "@postMenu")
        if let uid = post?.authorUID, coordinator.actions?.blocked.contains(uid) == true {
            add(RoomUI.label("This creator is blocked.", size: 16)); return
        }
        let cover: UIImageView
        if let post { cover = communityCover(post,ratio:1.02);add(cover) } else { cover = photo("reading-room",ratio:1.02) }
        cover.accessibilityIdentifier = "community.detail.cover"
        heading(post?.title ?? "My woven reading corner")
        add(makerRow(post?.author ?? "Maya",
            subtitle: post.map { $0.isMemberPost ? AppLanguage.text($0.visibility == "private" ? "Only me" : "Public") : $0.category } ?? "May 12, 2024 · At Home",
            asset: post == nil ? "maker" : (coordinator.community?.creators[post?.authorUID ?? ""]?.avatarID ?? "studio")))
        if let uid = post?.authorUID { add(RoomUI.button("View creator") { [weak self] in self?.coordinator.openCreator(uid) }) }
        add(RoomUI.label(post?.body ?? "A cozy corner made brighter with a handwoven throw. This simple weave completely changed the feel of my reading nook.", size: 16))
        let path = post.map { ($0.isMemberPost ? "memberPosts/" : "communityPosts/") + $0.id }
        if let path { coordinator.actions?.watchReaction(path) }
        let liked = path.map { coordinator.actions?.liked.contains($0) == true } ?? false
        let likes = path.flatMap { coordinator.actions?.counts[$0] }.map(String.init) ?? "—"
        let likeButton=action(likes,"@like",icon:liked ? "heart.fill" : "heart")
        likeButton.isEnabled=path.flatMap { coordinator.actions?.counts[$0] } != nil && !(path.map { coordinator.actions?.pending.contains($0) == true } ?? false)
        add(RoomUI.stack([
            likeButton,
            action("", "C04", icon: "bubble.left"),
            action("", "@share", icon: "square.and.arrow.up"),
            action("", "@save", icon: coordinator.store.state.saved.contains(post?.id ?? "C03") ? "bookmark.fill" : "bookmark")
        ], axis: .horizontal))
        if post?.isMemberPost == true {
            if let date = post?.publishedAt { add(RoomUI.label(date.formatted(date:.abbreviated,time:.shortened),size:12,color:.secondaryLabel)) }
            return
        }
        let tryMake = action("Try this make", "C10", primary: true, icon: "leaf")
        tryMake.configuration?.baseBackgroundColor = .roomYellow
        tryMake.configuration?.baseForegroundColor = .roomGreen
        let buttons = RoomUI.stack([action("View tutorial", "D04", primary: true, icon: "book"), tryMake], axis: .horizontal)
        buttons.distribution = .fillEqually
        add(buttons)
        add(RoomUI.stack([
            row(post?.category ?? "Reading corner", subtitle: post == nil ? "In my space" : "Make it your own", code: post == nil ? "S02" : "@editorialGuide"),
            row(post?.author ?? "Nora", subtitle: post == nil ? "Inspired by" : nil, code: "C05")
        ], axis: .horizontal))
    }

    func handleEditorialAction(_ code: String) -> Bool {
        guard screen.id == "C03", !editorialTutorial, let post = editorialPost else { return false }
        switch code {
        case "C05": if let uid = post.authorUID { coordinator.openCreator(uid) }
        case "@like":
            let path=(post.isMemberPost ? "memberPosts/" : "communityPosts/") + post.id
            coordinator.actions?.toggleLike(path) { [weak self] success in if !success { self?.coordinator.onlineFailure() } }
        case "@save": coordinator.saveToCollection(post.id)
        case "C04":
            guard let target = coordinator.catalog["C04"] else { return true }
            let next = ScreenViewController(screen: target, coordinator: coordinator)
            next.editorialPost = post
            next.commentKnowledgeID = (post.isMemberPost ? "member:" : "community:") + post.id
            next.commentKnowledgeTitle = post.title
            navigationController?.pushViewController(next, animated: UIView.areAnimationsEnabled && !UIAccessibility.isReduceMotionEnabled)
        case "@postMenu": coordinator.showContentMenu(from:self)
        case "@share":
            let sheet = UIActivityViewController(activityItems: [post.title + "\n\n" + post.body + "\n\n" + post.author], applicationActivities: nil)
            sheet.popoverPresentationController?.sourceView = view
            sheet.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
            present(sheet, animated: true)
        case "D04", "@editorialGuide", "C10":
            guard let target = coordinator.catalog[code == "C10" ? "C10" : "C03"] else { return true }
            let next = ScreenViewController(screen: target, coordinator: coordinator)
            next.editorialPost = post
            next.editorialTutorial = code != "C10"
            navigationController?.pushViewController(next, animated: UIView.areAnimationsEnabled && !UIAccessibility.isReduceMotionEnabled)
        default: return false
        }
        return true
    }

    func buildEditorialGuide(_ post: CommunityEditorialPost) {
        toolbar("View tutorial")
        let cover = photo(post.imageID, ratio: 0.9)
        cover.isAccessibilityElement = true
        cover.accessibilityLabel = post.title
        add(RoomUI.label(post.category, size: 13, color: .secondaryLabel))
        heading(post.title, subtitle: post.summary)
        add(RoomUI.label(post.author, size: 15, weight: .semibold))
        add(RoomUI.label(post.body, size: 16))
        add(RoomUI.label("What to gather", size: 21, weight: .bold))
        for item in post.materials { add(RoomUI.label("• " + item, size: 15)) }
        add(RoomUI.label("Make it your own", size: 21, weight: .bold))
        for (index, idea) in post.ideas.enumerated() {
            add(RoomUI.label("\(index + 1). \(idea)", size: 16))
        }
        add(RoomUI.card(RoomUI.stack([
            RoomUI.label("A note to keep", size: 17, weight: .semibold),
            RoomUI.label(post.reflection, size: 15)
        ])))
        let share = RoomUI.button("Share this idea", icon: "square.and.arrow.up") { [weak self] in
            guard let self else { return }
            let sheet = UIActivityViewController(activityItems: [post.title + "\n\n" + post.summary + "\n\n" + post.body + "\n\n" + post.author], applicationActivities: nil)
            sheet.popoverPresentationController?.sourceView = self.view
            sheet.popoverPresentationController?.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 1, height: 1)
            self.present(sheet, animated: true)
        }
        add(share)
    }
}
