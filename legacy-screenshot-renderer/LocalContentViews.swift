import UIKit

extension ScreenViewController {
    private func clearRegion(from y: CGFloat, height: CGFloat) {
        liveDataViews.forEach { $0.removeFromSuperview() }; liveDataViews.removeAll()
        for subview in content.subviews where !(subview is SurfaceView) && subview.frame.minY >= y { subview.isHidden = true }
        let cover = UIView(frame: CGRect(x: 0,y: y,width: screen.width,height: max(screen.height,height)-y))
        cover.backgroundColor = .roomCream; content.addSubview(cover); liveDataViews.append(cover)
        minimumContentHeight = height
    }
    private func addLive(_ view: UIView) { content.addSubview(view); liveDataViews.append(view) }
    private func liveLabel(_ text: String, x: CGFloat, y: CGFloat, width: CGFloat, size: CGFloat = 15, bold: Bool = false) -> UILabel {
        let label = UILabel(frame: CGRect(x: x,y: y,width: width,height: 42)); label.text = text; label.numberOfLines = 2
        label.font = .systemFont(ofSize: size, weight: bold ? .semibold : .regular); label.textColor = .label; return label
    }
    private func liveButton(_ title: String, y: CGFloat, action: @escaping ()->Void) -> UIButton {
        let button = UIButton(type: .system); button.frame = CGRect(x: 16,y: y,width: screen.width-32,height: 46)
        button.backgroundColor = .roomGreen; button.layer.cornerRadius = 14; button.setTitle(title, for: .normal); button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        button.addAction(UIAction { _ in action() }, for: .touchUpInside); return button
    }
    private func photo(_ name: String?) -> UIImage? {
        guard let name else { return nil }
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(name)
        return UIImage(contentsOfFile: url.path)
    }
    func refreshLocalLists() {
        switch screen.id {
        case "S01":
            let spaces = coordinator.store.state.spaces
            clearRegion(from: 163, height: 255+CGFloat(spaces.count)*235)
            for (index, name) in spaces.enumerated() {
                let y: CGFloat = 169+CGFloat(index)*235
                let card = UIButton(type: .custom); card.frame = CGRect(x: 15,y: y,width: screen.width-30,height: 217); card.backgroundColor = .white; card.layer.cornerRadius = 18; card.clipsToBounds = true
                let covers = screen.images.filter { $0.name.contains("media") }
                let fallback = covers.isEmpty ? nil : covers[index % covers.count]
                let image = UIImageView(image: photo(coordinator.store.state.spaceDetails?[name]?.afterPhoto) ?? fallback.flatMap { DesignCatalog.image($0.name) })
                image.frame = CGRect(x: 0,y: 0,width: card.bounds.width,height: 159); image.contentMode = .scaleAspectFill; image.clipsToBounds = true; card.addSubview(image)
                card.addSubview(liveLabel(name,x: 14,y: 163,width: card.bounds.width-55,size: 18,bold: true))
                let count = coordinator.store.state.projects.filter { $0.space == name }.count
                let detail = liveLabel("\(count) handmade pieces",x: 14,y: 189,width: card.bounds.width-55,size: 11); detail.frame.size.height = 20; detail.textColor = .secondaryLabel; card.addSubview(detail)
                card.accessibilityLabel = "\(name), \(count) pieces"; card.addAction(UIAction { [weak self] _ in self?.coordinator.openSpace(name) }, for: .touchUpInside)
                let more = UIButton(type: .system); more.frame = CGRect(x: card.bounds.width-42,y: 171,width: 40,height: 36); more.setTitle("•••", for: .normal); more.tintColor = .roomGreen
                more.menu = UIMenu(children: [UIAction(title: "Delete space", attributes: .destructive) { [weak self] _ in self?.coordinator.removeSpace(name) }]); more.showsMenuAsPrimaryAction = true; card.addSubview(more); addLive(card)
            }
            addLive(liveButton("+ Create space", y: 181+CGFloat(spaces.count)*235) { [weak self] in self?.coordinator.createSpace() })
        case "P02":
            let names = ["All saved"] + coordinator.store.state.collections
            clearRegion(from: 171, height: 245+CGFloat(names.count)*178)
            for (index,name) in names.enumerated() {
                let card = UIButton(type: .custom); card.frame = CGRect(x: 14,y: 176+CGFloat(index)*178,width: screen.width-28,height: 162); card.backgroundColor = .white; card.layer.cornerRadius = 16; card.clipsToBounds = true
                if let source = screen.images.first(where: { $0.name.contains("media") }) {
                    let image = UIImageView(image: DesignCatalog.image(source.name)); image.frame = CGRect(x: 0,y: 0,width: card.bounds.width,height: 104); image.contentMode = .scaleAspectFill; image.clipsToBounds = true; card.addSubview(image)
                }
                card.addSubview(liveLabel(name,x: 14,y: 105,width: card.bounds.width-55,size: 17,bold: true))
                let count = name == "All saved" ? coordinator.store.state.saved.count : (coordinator.store.state.collectionItems?[name]?.count ?? 0)
                let detail = liveLabel("\(count) items · Only you",x: 14,y: 138,width: 240,size: 11); detail.frame.size.height = 18; detail.textColor = .secondaryLabel; card.addSubview(detail)
                card.accessibilityLabel = "\(name), \(count) items"; card.addAction(UIAction { [weak self] _ in self?.coordinator.openCollection(name) }, for: .touchUpInside)
                if name != "All saved" {
                    let more = UIButton(type: .system); more.frame = CGRect(x: card.bounds.width-45,y: 116,width: 42,height: 34); more.setTitle("•••", for: .normal); more.tintColor = .roomGreen
                    more.menu = UIMenu(children: [UIAction(title: "Delete collection", attributes: .destructive) { [weak self] _ in self?.coordinator.removeCollection(name) }]); more.showsMenuAsPrimaryAction = true; card.addSubview(more)
                }
                addLive(card)
            }
            addLive(liveButton("+ New collection", y: 188+CGFloat(names.count)*178) { [weak self] in self?.coordinator.navigate("P10") })
        case "P09":
            let name = coordinator.selectedCollection
            let ids = name == "All saved" ? Array(coordinator.store.state.saved).sorted() : (coordinator.store.state.collectionItems?[name] ?? [])
            for (item,label) in labels {
                if item.text == "Weekend makes" { label.text = name }
                if item.text.contains("items •") { label.text = "\(ids.count) items · Only you" }
            }
            clearRegion(from: 360, height: max(600,400+CGFloat(ids.count)*100))
            if ids.isEmpty {
                addLive(liveLabel("Save a tutorial, space or post to keep it here.",x: 24,y: 385,width: screen.width-48,size: 18))
                addLive(liveButton("Explore ideas",y: 468) { [weak self] in self?.coordinator.navigate("D01") })
            }
            for (index,id) in ids.enumerated() {
                guard let target = coordinator.catalog[id] else { continue }
                let row = UIButton(type: .custom); row.frame = CGRect(x: 16,y: 369+CGFloat(index)*100,width: screen.width-32,height: 86); row.backgroundColor = .white; row.layer.cornerRadius = 13
                if let source = target.images.first(where: { $0.name.contains("media") && $0.box[2]>65 }) {
                    let image = UIImageView(image: DesignCatalog.image(source.name)); image.frame = CGRect(x: 8,y: 8,width: 70,height: 70); image.contentMode = .scaleAspectFill; image.clipsToBounds = true; image.layer.cornerRadius = 9; row.addSubview(image)
                }
                row.addSubview(liveLabel(target.name,x: 90,y: 18,width: row.bounds.width-106,size: 16,bold: true))
                row.accessibilityLabel = target.name; row.addAction(UIAction { [weak self] _ in self?.coordinator.navigate(id) }, for: .touchUpInside); addLive(row)
            }
        case "S02":
            liveDataViews.forEach { $0.removeFromSuperview() }; liveDataViews.removeAll()
            let name = coordinator.selectedSpace
            for (item,label) in labels {
                if item.text == "Reading corner" { label.text = name }
                if item.text.hasPrefix("A cozy spot") { label.text = coordinator.store.state.spaceDetails?[name]?.notes ?? "A space for your handmade pieces." }
                if item.text == "and good books." { label.text = "" }
            }
            let details = coordinator.store.state.spaceDetails?[name]
            if let image = photo(coordinator.showingBeforePhoto ? details?.beforePhoto : details?.afterPhoto) {
                let iv = UIImageView(image: image); iv.frame = CGRect(x: 15,y: 161,width: 299,height: 376); iv.contentMode = .scaleAspectFill; iv.clipsToBounds = true; iv.layer.cornerRadius = 18; addLive(iv)
            }
            let cover = UIView(frame: CGRect(x: 0,y: 624,width: screen.width,height: 150)); cover.backgroundColor = .roomCream; addLive(cover)
            let projects = coordinator.store.state.projects.filter { $0.space == name }
            if projects.isEmpty { addLive(liveLabel("No pieces yet. Finish a make and add it here.",x: 20,y: 650,width: screen.width-40,size: 17)) }
            for (index,p) in projects.prefix(2).enumerated() {
                let button = UIButton(type: .system); button.frame = CGRect(x: 15+CGFloat(index)*160,y: 641,width: 143,height: 121); button.backgroundColor = .white; button.layer.cornerRadius = 14
                button.setTitle(p.name, for: .normal); button.titleLabel?.numberOfLines = 3; button.tintColor = .roomGreen
                button.addAction(UIAction { [weak self] _ in self?.coordinator.openProject(p.id) }, for: .touchUpInside); addLive(button)
            }
        case "S03":
            if liveDataViews.isEmpty {
                let photoButton = liveButton("Choose a space photo", y: 160) { [weak self] in self?.coordinator.pickPhoto(context: "S03") }
                addLive(photoButton)
            }
        case "P04":
            liveDataViews.forEach { $0.removeFromSuperview() }; liveDataViews.removeAll()
            if let image = photo(coordinator.store.state.profilePhoto) {
                let avatar = UIImageView(image: image); avatar.frame = CGRect(x: 108,y: 174,width: 115,height: 115); avatar.contentMode = .scaleAspectFill; avatar.layer.cornerRadius = 57.5; avatar.clipsToBounds = true; addLive(avatar)
            }
            let button = UIButton(type: .custom); button.frame = CGRect(x: 78,y: 142,width: 177,height: 191); button.accessibilityLabel = "Change profile photo"
            button.addAction(UIAction { [weak self] _ in self?.coordinator.pickPhoto(context: "P04") }, for: .touchUpInside); addLive(button)
        case "M06":
            liveDataViews.forEach { $0.removeFromSuperview() }; liveDataViews.removeAll()
            if let project = coordinator.currentProject {
                for (item,label) in labels {
                    if item.text == "Found a nice natural" { label.text = project.notes.isEmpty ? "Your notes will appear here." : project.notes }
                    if ["dye tone for the green.","Apr 12, 2024","Started the base layer","today. Loving the texture!","Apr 10, 2024"].contains(item.text) { label.text = "" }
                }
                if let image = photo(coordinator.store.state.projectPhotos?[project.id.uuidString]?.last) {
                    let iv = UIImageView(image: image); iv.frame = CGRect(x: 14,y: 226,width: 325,height: 148); iv.contentMode = .scaleAspectFill; iv.clipsToBounds = true; iv.layer.cornerRadius = 14; addLive(iv)
                }
            }
        default: break
        }
        view.setNeedsLayout()
    }
}
