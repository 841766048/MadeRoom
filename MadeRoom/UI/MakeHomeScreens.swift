import UIKit

extension ScreenViewController {
    func buildMakeHome() {
        body.spacing = 12
        let header = RoomUI.stack(axis: .horizontal, spacing: 0)
        let words = RoomUI.stack([RoomUI.label("Made Room", size: 28, weight: .bold), RoomUI.label("Make a calmer, brighter home\nwith your hands.", size: 14)], spacing: 6)
        let art = RoomUI.image("make-shelf", ratio: 1, radius: 0)
        art.widthAnchor.constraint(equalToConstant: 130).isActive = true
        header.addArrangedSubview(words); header.addArrangedSubview(art); header.alignment = .center
        add(header)
        let tabs = UISegmentedControl(items: ["In progress", "Finished"].map(AppLanguage.text))
        tabs.selectedSegmentIndex = min(segment, 1); tabs.selectedSegmentTintColor = .roomYellow
        tabs.accessibilityIdentifier = "make.filter"
        tabs.addAction(UIAction { [weak self, weak tabs] _ in self?.segment = tabs?.selectedSegmentIndex ?? 0; self?.refresh() }, for: .valueChanged)
        let create = action("New project", "M02", primary: true, icon: "plus")
        create.configuration?.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in var attributes = attributes; attributes.font = .systemFont(ofSize: 12, weight: .semibold); return attributes }
        create.widthAnchor.constraint(equalToConstant: 124).isActive = true
        let controls = RoomUI.stack([tabs, create], axis: .horizontal, spacing: 12); controls.alignment = .fill; add(controls)
        let projects = coordinator.store.state.projects.filter { project in
            coordinator.store.state.archivedProjects?.contains(project.id) != true && (segment == 1 ? project.isComplete : !project.isComplete)
        }
        for project in projects {
            let photo = RoomUI.image(project.name.localizedCaseInsensitiveContains("clay") ? "make-clay" : "make-weave", ratio: 1.06, radius: 10)
            if let name = coordinator.store.state.projectPhotos?[project.id.uuidString]?.last, let image = localPhoto(name) { photo.image = image }
            photo.widthAnchor.constraint(equalToConstant: 110).isActive = true
            let open = RoomUI.button(project.name) { [weak self] in self?.coordinator.openProject(project.id) }
            open.accessibilityIdentifier = "project.\(project.id)"; open.contentHorizontalAlignment = .leading
            open.configuration?.baseForegroundColor = .label
            let progress = UIProgressView(progressViewStyle: .bar)
            progress.progress = Float(project.completedSteps) / Float(max(project.totalSteps, 1)); progress.progressTintColor = .roomGreen
            progress.trackTintColor = UIColor(white: 0.91, alpha: 1); progress.heightAnchor.constraint(equalToConstant: 7).isActive = true
            progress.layer.cornerRadius = 3.5; progress.clipsToBounds = true
            let space = RoomUI.label("⌂  " + (project.space ?? "No space yet"), size: 12, color: .secondaryLabel)
            let menu = RoomUI.button("", icon: "ellipsis") { [weak self] in
                guard let self else { return }; self.coordinator.selectProject(project.id)
                self.act("@projectMenu")
            }
            menu.accessibilityLabel = AppLanguage.text("More") + " · " + project.name
            let details = RoomUI.stack([open, RoomUI.label("\(project.completedSteps) of \(project.totalSteps) steps", size: 13, color: .secondaryLabel), progress, RoomUI.stack([space, menu], axis: .horizontal, spacing: 0)], spacing: 4)
            let row = RoomUI.stack([photo, details], axis: .horizontal, spacing: 14); row.alignment = .center
            add(RoomUI.card(row, inset: 8))
        }
        if projects.isEmpty { add(RoomUI.card(RoomUI.label(segment == 0 ? "Your next make starts here." : "Your finished makes will appear here.", size: 16))) }
        let vase = RoomUI.image("make-vase", ratio: 0.75, radius: 0); vase.widthAnchor.constraint(equalToConstant: 130).isActive = true
        let banner = RoomUI.card(RoomUI.stack([RoomUI.label("Small projects.\nA happier home.", size: 18, weight: .semibold), vase], axis: .horizontal, spacing: 0), inset: 12)
        banner.backgroundColor = UIColor(red: 0.90, green: 0.91, blue: 0.97, alpha: 1); banner.clipsToBounds = true; add(banner)
        if !(coordinator.store.state.archivedProjects ?? []).isEmpty {
            let archived = RoomUI.button("Archived projects") { [weak self] in self?.showArchivedMakes() }; add(archived)
        }
    }
    private func showArchivedMakes() {
        let sheet = RoomDialogController(title: "Archived projects", message: nil, preferredStyle: .actionSheet)
        for project in coordinator.store.state.projects where coordinator.store.state.archivedProjects?.contains(project.id) == true {
            sheet.addAction(RoomDialogAction(title: project.name, style: .default) { [weak self] _ in self?.coordinator.openProject(project.id) })
        }
        sheet.addAction(RoomDialogAction(title: "Cancel", style: .cancel)); present(sheet, animated: true)
    }
    func buildMakeEmpty() {
        body.spacing = 12
        add(RoomUI.label("Make", size: 34, weight: .bold))
        add(RoomUI.label("Turn your ideas into a more\nhomespun you.", size: 16, color: .secondaryLabel))
        add(RoomUI.image("make-empty", ratio: 0.65, radius: 0))
        let title = RoomUI.label("Your first make\nstarts here.", size: 26, weight: .bold); title.textAlignment = .center; add(title)
        let copy = RoomUI.label("Find step-by-step tutorials, save ideas,\nand start your own project.", size: 16); copy.textAlignment = .center; add(copy)
        let browse = action("Browse tutorials", "D04", primary: true); browse.configuration?.background.cornerRadius = 24; add(browse)
        let create = action("Create project", "M02"); create.layer.cornerRadius = 24; create.layer.borderColor = UIColor.roomGreen.cgColor; create.layer.borderWidth = 1; add(create)
        add(RoomUI.label("Need inspiration?", size: 16, weight: .semibold))
        let cards = RoomUI.stack(axis: .horizontal, spacing: 10); cards.distribution = .fillEqually
        for (asset, title) in [("make-basket", "Easy basket\nin a weekend"), ("make-flowers", "Clay vase\nfor beginners"), ("make-pillow", "Sew a pillow\ncover")] {
            let card = RoomUI.stack([RoomUI.image(asset, ratio: 0.76, radius: 8), RoomUI.label(title, size: 11)], spacing: 4)
            cards.addArrangedSubview(card)
        }
        add(cards)
    }
}
