import UIKit
import IQKeyboardManagerSwift

extension ScreenViewController {
    func buildDesignedComments() {
        toolbar("Comments", trailing: "ellipsis", action: "@postMenu")
        body.spacing = 10
        let cover: UIView
        if let article = editorialPost {
            cover = communityCover(article, ratio: 1)
            cover.widthAnchor.constraint(equalToConstant: 66).isActive = true
        } else { cover = commentAvatar("comment-post", size: 66, radius: 9) }
        let post = action(commentKnowledgeTitle, "C03"); post.configuration?.baseForegroundColor = .label
        post.isUserInteractionEnabled = commentKnowledgeID == "woven-reading-corner"
        post.configuration?.contentInsets = .zero; post.contentHorizontalAlignment = .leading
        let text = RoomUI.stack([post, RoomUI.label(editorialPost == nil ? "Knowledge discussion" : "Community discussion", size: 12, color: .secondaryLabel)], spacing: 0)
        let summary = RoomUI.stack([cover, text], axis: .horizontal, spacing: 12); summary.alignment = .center
        add(RoomUI.card(summary, inset: 10))
        let oldest = coordinator.store.state.preferences["comments.oldest"] == true
        let sort = RoomUI.button(oldest ? "Oldest" : "Newest", icon: "chevron.down") {}
        sort.accessibilityIdentifier = "comments.sort"; sort.configuration?.imagePlacement = .trailing; sort.configuration?.baseForegroundColor = .label
        sort.widthAnchor.constraint(equalToConstant: 104).isActive = true
        sort.menu = UIMenu(children: [UIAction(title: AppLanguage.text("Newest")) { [weak self] _ in self?.sortComments(false) }, UIAction(title: AppLanguage.text("Oldest")) { [weak self] _ in self?.sortComments(true) }])
        sort.showsMenuAsPrimaryAction = true
        commentCountLabel = RoomUI.label("Comments", size: 16, weight: .semibold)
        let header = RoomUI.stack([commentCountLabel, sort], axis: .horizontal); header.alignment = .center; add(header)
        commentStatusLabel = RoomUI.label("Connecting…", size: 12, color: .secondaryLabel)
        commentStatusLabel.accessibilityIdentifier = "comments.status"
        add(commentStatusLabel)
        add(RoomUI.button("Retry connection") { [weak self] in
            guard let self else { return }; self.coordinator.comments?.listen(to: self.commentKnowledgeID)
        })
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitesting"), ProcessInfo.processInfo.arguments.contains("--auth-emulator") {
            for enabled in [false, true] {
                let button = RoomUI.button(enabled ? "Test online" : "Test offline") { [weak self] in self?.coordinator.comments?.setTestNetworkEnabled(enabled) }
                button.accessibilityIdentifier = enabled ? "comments.test.online" : "comments.test.offline"
                add(button)
            }
        }
        #endif
        commentsFeed = RoomUI.stack(spacing: 10); add(commentsFeed)
        renderCommentFeed()
        installCommentComposer()
    }
    func renderCommentFeed() {
        guard isViewLoaded, screen.id == "C04" else { return }
        let offset = scroll.contentOffset
        commentsFeed.arrangedSubviews.forEach { $0.removeFromSuperview() }
        commentCountLabel.text = "\(discussionComments.count) comments loaded"
        commentStatusLabel.text = coordinator.comments?.status ?? "Sign in to sync comments"
        let all = discussionComments
        let ids = Set(all.map(\.id))
        for comment in all.filter({ item in item.parentID == nil || !ids.contains(item.parentID ?? "") }) {
            commentsFeed.addArrangedSubview(commentThread(comment.id, [localCommentRow(comment)]))
        }
        if coordinator.comments?.hasMore == true {
            commentsFeed.addArrangedSubview(RoomUI.button("Load older comments") { [weak self] in self?.coordinator.comments?.loadMore() })
        }
        view.layoutIfNeeded()
        scroll.setContentOffset(offset, animated: false)
    }
    private func commentAvatar(_ asset: String, size: CGFloat, radius: CGFloat? = nil) -> UIImageView {
        let image = EditorialImageView(asset: asset); image.contentMode = .scaleAspectFill; image.clipsToBounds = true
        image.layer.cornerRadius = radius ?? size / 2; image.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([image.widthAnchor.constraint(equalToConstant: size), image.heightAnchor.constraint(equalToConstant: size)])
        return image
    }
    private func commentRow(id: String, name: String, asset: String, age: String, text: String, likes: Int, author: Bool = false, local: Bool = false, mine: Bool = true) -> UIView {
        let avatar = commentAvatar(asset, size: author || local ? 34 : 42)
        if local && !mine { avatar.image = UIImage(systemName: "person.crop.circle") }
        if local && mine, let photo = profilePhoto() { avatar.image = photo }
        let nameLabel = RoomUI.label(name, size: 14, weight: .semibold)
        nameLabel.text = name
        let ageLabel = RoomUI.label(age, size: 11, color: .secondaryLabel)
        let heading = RoomUI.stack([nameLabel, ageLabel], axis: .horizontal, spacing: 8); heading.alignment = .center
        nameLabel.setContentHuggingPriority(.required, for: .horizontal)
        if author {
            let badge = RoomUI.card(RoomUI.label("Author", size: 10), inset: 4); badge.backgroundColor = UIColor(red: 1, green: 0.92, blue: 0.88, alpha: 1); badge.layer.cornerRadius = 9; heading.addArrangedSubview(badge)
        }
        heading.addArrangedSubview(UIView())
        let reply = RoomUI.button("Reply") { [weak self] in
            guard let self else { return }; self.commentReplyTo = name; self.commentReplyParentID = self.discussionComments.first(where: { $0.id == id })?.parentID ?? (id.hasPrefix("maya-") ? String(id.dropFirst(5)) : id)
            self.fields["comment"]?.placeholder = AppLanguage.text("Reply") + " · " + name
            self.fields["comment"]?.becomeFirstResponder()
            self.view.viewWithTag(904)?.isHidden = false
        }
        reply.configuration?.baseForegroundColor = .label; reply.contentHorizontalAlignment = .leading
        reply.accessibilityIdentifier = "comment.reply.\(id)"
        let path = "knowledge/" + commentKnowledgeID + "/comments/" + id
        let online = discussionComments.first(where:{$0.id == id})?.syncState == "synced"
        if online { coordinator.actions?.watchReaction(path) }
        let liked = coordinator.actions?.liked.contains(path) == true
        let count = coordinator.actions?.counts[path].map(String.init) ?? "—"
        let like = RoomUI.button(count, icon: liked ? "heart.fill" : "heart") { [weak self] in
            self?.coordinator.actions?.toggleLike(path) { [weak self] success in if !success { self?.coordinator.onlineFailure() } }
        }
        like.isEnabled = online && coordinator.actions?.counts[path] != nil && coordinator.actions?.pending.contains(path) != true
        like.configuration?.baseForegroundColor = liked ? .systemRed : .secondaryLabel; like.accessibilityIdentifier = "comment.like.\(id)"
        like.accessibilityLabel = AppLanguage.text(liked ? "Unlike comment" : "Like comment") + ", " + count
        let more = RoomUI.button("", icon: "ellipsis") {}; more.configuration?.baseForegroundColor = .secondaryLabel
        more.accessibilityLabel = AppLanguage.text("More")
        let owner = discussionComments.first(where:{$0.id == id})?.authorUID ?? ""
        more.menu = UIMenu(children: online ? [UIAction(title: AppLanguage.text("Report content")) { [weak self] _ in self?.coordinator.prepareReport(path:path,owner:owner) }] : []); more.showsMenuAsPrimaryAction = true
        let actions = RoomUI.stack([reply, UIView(), like, more], axis: .horizontal, spacing: 6)
        let bodyLabel = RoomUI.label(text, size: 14); if local { bodyLabel.text = text }
        let content = RoomUI.stack([heading, bodyLabel, actions], spacing: 4)
        let row = RoomUI.stack([avatar, content], axis: .horizontal, spacing: 10); row.alignment = .top
        row.accessibilityIdentifier = "comment.\(id)"
        if !author { return row }
        let wrapper = UIView(); row.translatesAutoresizingMaskIntoConstraints = false; wrapper.addSubview(row)
        let line = UIView(); line.backgroundColor = UIColor(white: 0.93, alpha: 1); line.translatesAutoresizingMaskIntoConstraints = false; wrapper.addSubview(line)
        NSLayoutConstraint.activate([row.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 36), row.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor), row.topAnchor.constraint(equalTo: wrapper.topAnchor), row.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor), line.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 20), line.widthAnchor.constraint(equalToConstant: 1), line.topAnchor.constraint(equalTo: wrapper.topAnchor), line.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -16)])
        return wrapper
    }
    private var discussionComments: [LocalComment] {
        let legacy = coordinator.store.state.comments.enumerated().map { index, text -> LocalComment in
            for (name, parent) in [("Tessa Kim", "tessa"), ("Elena Cruz", "elena"), ("Priya Shah", "priya"), ("Maya", "tessa")] {
                for prefix in ["Reply · \(name): ", "回复 · \(name): "] where text.hasPrefix(prefix) {
                    return LocalComment(id: "legacy.\(index)", parentID: parent, replyTo: name, text: String(text.dropFirst(prefix.count)))
                }
            }
            return LocalComment(id: "legacy.\(index)", parentID: nil, replyTo: nil, text: text)
        }
        let local = (coordinator.store.state.localComments ?? []).filter { ($0.knowledgeID ?? "woven-reading-corner") == commentKnowledgeID }
        let remote = coordinator.comments?.knowledgeID == commentKnowledgeID ? (coordinator.comments?.remote ?? []) : []
        var byID = Dictionary(uniqueKeysWithValues: ((commentKnowledgeID == "woven-reading-corner" ? legacy : []) + local).map { ($0.id, $0) })
        for entry in remote { byID[entry.id] = entry }
        let oldest = coordinator.store.state.preferences["comments.oldest"] == true
        return byID.values.filter { coordinator.actions?.blocked.contains($0.authorUID ?? "") != true }.sorted {
            let a = $0.createdAt ?? .distantPast, b = $1.createdAt ?? .distantPast
            return a == b ? $0.id < $1.id : (oldest ? a < b : a > b)
        }
    }
    private func localCommentRow(_ comment: LocalComment) -> UIView {
        let age: String
        if let date = comment.createdAt {
            let formatter = RelativeDateTimeFormatter(); formatter.locale = Locale(identifier: AppLanguage.isChinese ? "zh_CN" : "en_US")
            age = formatter.localizedString(for: date, relativeTo: Date())
        } else { age = "" }
        let row = commentRow(id: comment.id, name: comment.authorName ?? coordinator.store.state.profileName, asset: "comment-maya", age: age, text: comment.text, likes: 0, local: true, mine: comment.authorUID == nil || comment.authorUID == coordinator.comments?.uid)
        row.accessibilityIdentifier = "comment.local.\(comment.id)"
        let state = comment.syncState ?? "local"
        let label = RoomUI.label(state == "synced" ? "Synced" : (state == "pending" ? "Waiting to sync" : (state == "failed" ? "Send failed" : "Saved on this device")), size: 11, color: .secondaryLabel)
        label.accessibilityIdentifier = "comment.sync.\(comment.id)"
        let wrapper = RoomUI.stack([row, label], spacing: 4)
        if state == "failed" || state == "pending" {
            wrapper.addArrangedSubview(RoomUI.button("Retry sending") { [weak self] in self?.coordinator.comments?.retry(comment.id) })
        }
        return wrapper
    }
    private func commentThread(_ id: String, _ rows: [UIView]) -> UIView {
        let stack = RoomUI.stack(rows, spacing: 8)
        for comment in discussionComments.filter({ $0.parentID == id }) {
            let row = localCommentRow(comment); let inset = UIView(); row.translatesAutoresizingMaskIntoConstraints = false; inset.addSubview(row)
            NSLayoutConstraint.activate([row.leadingAnchor.constraint(equalTo: inset.leadingAnchor, constant: 36), row.trailingAnchor.constraint(equalTo: inset.trailingAnchor), row.topAnchor.constraint(equalTo: inset.topAnchor), row.bottomAnchor.constraint(equalTo: inset.bottomAnchor)])
            stack.addArrangedSubview(inset)
        }
        return RoomUI.card(stack, inset: 12)
    }
    private func sortComments(_ oldest: Bool) {
        coordinator.perform { try coordinator.store.setPreference("comments.oldest", value: oldest) }; refresh()
    }
    private func installCommentComposer() {
        let footer = UIView(); footer.backgroundColor = .roomCream; footer.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(footer); profileFooter = footer
        let input = UITextField(); input.font = .systemFont(ofSize: 14); input.placeholder = commentReplyTo.map { AppLanguage.text("Reply") + " · " + $0 } ?? AppLanguage.text("Add a comment…")
        input.backgroundColor = .white; input.layer.cornerRadius = 19; input.layer.borderColor = UIColor(white: 0.88, alpha: 1).cgColor; input.layer.borderWidth = 0.5
        input.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 38)); input.leftViewMode = .always
        // The composer follows keyboardLayoutGuide; do not also move the page.
        input.iq.enableMode = .disabled
        input.heightAnchor.constraint(equalToConstant: 40).isActive = true; input.accessibilityIdentifier = "input.comment"; input.accessibilityLabel = AppLanguage.text("Add a comment…"); fields["comment"] = input
        let send = RoomUI.button("", icon: "paperplane.fill", primary: true) { [weak self] in self?.saveCommentDraft() }
        send.accessibilityIdentifier = "comment.send"; send.accessibilityLabel = AppLanguage.isChinese ? "发送评论" : "Send comment"
        send.configuration?.cornerStyle = .capsule
        let avatar = commentAvatar("comment-maya", size: 34)
        if let photo = profilePhoto() { avatar.image = photo }
        let cancel = RoomUI.button("", icon: "xmark") { [weak self, weak input] in self?.commentReplyTo = nil; self?.commentReplyParentID = nil; input?.placeholder = AppLanguage.text("Add a comment…"); self?.view.viewWithTag(904)?.isHidden = true }
        cancel.tag = 904; cancel.isHidden = commentReplyTo == nil; cancel.accessibilityLabel = AppLanguage.text("Cancel reply")
        let row = RoomUI.stack([avatar, input, cancel, send], axis: .horizontal, spacing: 8); row.alignment = .center; row.translatesAutoresizingMaskIntoConstraints = false; footer.addSubview(row)
        let bottom = footer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor); bottom.priority = .defaultHigh
        NSLayoutConstraint.activate([footer.leadingAnchor.constraint(equalTo: view.leadingAnchor), footer.trailingAnchor.constraint(equalTo: view.trailingAnchor), footer.bottomAnchor.constraint(lessThanOrEqualTo: view.keyboardLayoutGuide.topAnchor), bottom, row.leadingAnchor.constraint(equalTo: footer.leadingAnchor, constant: 16), row.trailingAnchor.constraint(equalTo: footer.trailingAnchor, constant: -16), row.topAnchor.constraint(equalTo: footer.topAnchor, constant: 10), row.bottomAnchor.constraint(equalTo: footer.bottomAnchor, constant: -10), scroll.bottomAnchor.constraint(equalTo: footer.topAnchor)])
    }
    private func saveCommentDraft() {
        let text = (fields["comment"]?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { fields["comment"]?.becomeFirstResponder(); return }
        coordinator.perform {
            guard let sync = coordinator.comments else { return }
            let commentID = try sync.post(text: text, name: coordinator.store.state.profileName, parentID: commentReplyParentID, replyTo: commentReplyTo)
            fields["comment"]?.text = ""; commentReplyTo = nil; commentReplyParentID = nil; view.endEditing(true); refresh()
            view.layoutIfNeeded()
            func find(_ view: UIView) -> UIView? {
                if view.accessibilityIdentifier == "comment.local.\(commentID)" { return view }
                return view.subviews.lazy.compactMap { find($0) }.first
            }
            if let reply = find(body) { scroll.scrollRectToVisible(reply.convert(reply.bounds, to: scroll).insetBy(dx: 0, dy: -12), animated: false) }
        }
    }
}

