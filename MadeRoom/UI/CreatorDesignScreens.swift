import UIKit

extension ScreenViewController {
    private func creatorPhoto(_ name: String, size: CGFloat) -> UIImageView {
        let image = RoomUI.image(name, ratio: 1, radius: size / 2)
        image.widthAnchor.constraint(equalToConstant: size).isActive = true
        return image
    }
    func creatorFollow(_ uid: String) -> UIButton {
        let social = coordinator.community
        let followed = social?.following[social?.uid ?? ""]?.contains(uid) == true
        let busy = social?.pending.contains(uid) == true
        let button = RoomUI.button(busy ? "Updating…" : (followed ? "Following" : "Follow"), primary: true) { [weak self] in
            self?.coordinator.community?.toggleFollow(uid)
        }
        button.accessibilityIdentifier = "creator.follow.\(uid)"
        button.isEnabled = social?.following[social?.uid ?? ""] != nil && !busy && uid != social?.uid && coordinator.actions?.blocked.contains(uid) != true
        button.configuration?.baseBackgroundColor = followed ? UIColor(red: 0.92, green: 0.94, blue: 0.91, alpha: 1) : .roomGreen
        button.configuration?.baseForegroundColor = followed ? .roomGreen : .white
        button.configuration?.titleTextAttributesTransformer = .init { a in var a = a; a.font = .systemFont(ofSize: 13, weight: .medium); return a }
        return button
    }
    private func creatorTabs(_ names: [String], selected: Int, change: @escaping (Int) -> Void) -> UIView {
        let row = RoomUI.stack(axis: .horizontal, spacing: 8); row.distribution = .fillEqually
        for (index, name) in names.enumerated() {
            let button = RoomUI.button(name) { change(index) }; button.configuration?.baseForegroundColor = .label
            button.accessibilityIdentifier = "creator.tab.\(index)"; button.accessibilityTraits = selected == index ? [.button, .selected] : [.button]
            let line = UIView(); line.heightAnchor.constraint(equalToConstant: 3).isActive = true; line.backgroundColor = selected == index ? .roomGreen : .clear; line.layer.cornerRadius = 1.5
            row.addArrangedSubview(RoomUI.stack([button, line], spacing: 0))
        }
        return row
    }
    func socialStatus() {
        guard let social = coordinator.community else { return }
        let waiting = !social.feedReady || social.following[social.uid] == nil || social.followers[social.uid] == nil
        guard waiting || !social.status.isEmpty else { return }
        let label = RoomUI.label(social.status.isEmpty ? "Connect to sync community." : social.status, size: 14, color: .secondaryLabel)
        label.accessibilityIdentifier = "community.sync.status"; add(label)
        if waiting || social.status.contains("Retry") || social.status.contains("try again") {
            add(RoomUI.button("Retry") { [weak self] in
                guard let self else { return }
                self.coordinator.community?.retry(name: self.coordinator.store.state.profileName, biography: self.coordinator.store.state.biography)
            })
        }
    }
    func buildCreatorProfile() {
        toolbar("", trailing: "ellipsis", action: "@postMenu"); body.spacing = 12
        guard let social = coordinator.community else { return }
        let uid = creatorUID ?? coordinator.selectedCreatorUID
        social.watch(uid)
        guard let person = social.creators[uid] else { add(RoomUI.label("Loading creator…", size: 16)); socialStatus(); return }
        let header = RoomUI.stack([creatorPhoto(person.avatarID, size: 106), UIView()], axis: .horizontal); header.alignment = .center
        if uid != social.uid { let follow = creatorFollow(uid); follow.widthAnchor.constraint(equalToConstant: 132).isActive = true; header.addArrangedSubview(follow) }
        add(header)
        add(RoomUI.label(person.displayName, size: 28, weight: .bold))
        add(RoomUI.label(person.biography, size: 15, color: .secondaryLabel))
        if coordinator.actions?.blocked.contains(uid) == true {
            add(RoomUI.label("This creator is blocked.",size:15,color:.secondaryLabel))
            add(RoomUI.button("Unblock creator") { [weak self] in self?.coordinator.blockCreator(uid,active:false) });return
        }
        let posts = social.posts.filter { $0.authorUID == uid }
        let statistics = RoomUI.stack(axis: .horizontal); statistics.distribution = .fillEqually
        let pairs = [(social.feedReady ? String(posts.count) : "—", "Posts"), (social.followers[uid].map { String($0.count) } ?? "—", "Followers"), (social.following[uid].map { String($0.count) } ?? "—", "Following")]
        for (index, pair) in pairs.enumerated() {
            let button = RoomUI.button(pair.0 + "\n" + AppLanguage.text(pair.1)) { [weak self] in
                guard let self, index > 0 else { return }
                self.coordinator.openConnections(uid: uid, tab: index - 1)
            }
            button.titleLabel?.numberOfLines = 2; button.accessibilityIdentifier = "creator.stat.\(index)"
            statistics.addArrangedSubview(button)
        }
        add(statistics); socialStatus()
        if social.feedReady && posts.isEmpty { add(RoomUI.label("No posts yet.", size: 15, color: .secondaryLabel)) }
        for post in posts { add(editorialCard(post)) }
    }
    func buildCreatorConnections() {
        guard let social = coordinator.community else { toolbar("Community"); return }
        let uid = creatorUID ?? coordinator.selectedCreatorUID
        social.watch(uid)
        toolbar(social.creators[uid]?.displayName ?? "Community"); body.spacing = 10
        let selected = segment
        let followers = social.followers[uid], following = social.following[uid]
        add(creatorTabs(["Followers (\(followers.map { String($0.count) } ?? "—"))", "Following (\(following.map { String($0.count) } ?? "—"))"], selected: selected) { [weak self] index in self?.segment = index; self?.refresh() })
        socialStatus()
        guard let people = selected == 0 ? followers : following else { add(RoomUI.label("Loading relationships…", size: 15)); return }
        if people.isEmpty { add(RoomUI.label(selected == 0 ? "No followers yet." : "Not following anyone yet.", size: 16, color: .secondaryLabel)) }
        for id in people.sorted() where coordinator.actions?.blocked.contains(id) != true { addCreatorRow(id) }
    }
    func addCreatorRow(_ id: String) {
        guard let social = coordinator.community else { return }
        let person = social.creators[id]
        let avatar = creatorPhoto(person?.avatarID ?? "studio", size: 46)
        let open = RoomUI.button(person?.displayName ?? "Member") { [weak self] in self?.coordinator.openCreator(id) }
        open.contentHorizontalAlignment = .leading; open.accessibilityIdentifier = "creator.open.\(id)"
        let info = RoomUI.stack([open, RoomUI.label(person?.biography ?? "", size: 12, color: .secondaryLabel)], spacing: 2)
        let row = RoomUI.stack([avatar, info], axis: .horizontal, spacing: 8); row.alignment = .center
        if id != social.uid { let follow = creatorFollow(id); follow.widthAnchor.constraint(equalToConstant: 100).isActive = true; row.addArrangedSubview(follow) }
        row.accessibilityIdentifier = "connection.\(id)"; add(row); add(RoomUI.divider())
    }
}
