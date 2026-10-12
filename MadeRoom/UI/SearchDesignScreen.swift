import UIKit

private struct SearchExample {
    let id: String, title: String, subtitle: String, asset: String
    let level: Int, minutes: Int
}
private let searchExamples = [
    SearchExample(id: "D04", title: "Woven wall hanging", subtitle: "A modern texture for\nany space.", asset: "search-wall", level: 1, minutes: 90),
    SearchExample(id: "example.baskets", title: "Woven storage baskets", subtitle: "Simple, useful, beautiful.", asset: "search-baskets", level: 1, minutes: 120),
    SearchExample(id: "example.basics", title: "Weaving basics", subtitle: "Learn the fundamentals\nat home.", asset: "search-basics", level: 1, minutes: 60),
    SearchExample(id: "example.placemats", title: "Woven placemats", subtitle: "A weekend make for\nyour table.", asset: "search-placemats", level: 2, minutes: 180)
]

extension ScreenViewController {
    func buildSearchDesign() {
        toolbar("")
        navigationItem.leftBarButtonItem?.tintColor = .label
        if #available(iOS 26.0, *) { navigationItem.leftBarButtonItem?.hidesSharedBackground = true }
        let query = UITextField(); query.placeholder = AppLanguage.text("Search ideas, projects, people…")
        query.font = .systemFont(ofSize: 15); query.returnKeyType = .search; query.clearButtonMode = .whileEditing
        query.accessibilityIdentifier = "input.query"; query.accessibilityLabel = AppLanguage.text("Search")
        query.backgroundColor = UIColor(white: 0.93, alpha: 1); query.layer.cornerRadius = 16
        let icon = UIImageView(image: UIImage(systemName: "magnifyingglass")); icon.tintColor = .secondaryLabel
        let inset = UIView(frame: CGRect(x: 0, y: 0, width: 34, height: 36)); icon.frame = CGRect(x: 10, y: 10, width: 17, height: 17); inset.addSubview(icon)
        query.leftView = inset; query.leftViewMode = .always
        query.heightAnchor.constraint(equalToConstant: 38).isActive = true
        navigationItem.titleView = query; fields["query"] = query
        query.addAction(UIAction { [weak self] _ in self?.showSearchResults() }, for: .editingChanged)
        query.addAction(UIAction { [weak self, weak query] _ in guard let self else { return }; query?.resignFirstResponder(); self.coordinator.search(query?.text ?? "", from: self) }, for: .editingDidEndOnExit)
        let categories = RoomUI.stack(axis: .horizontal, spacing: 8); categories.distribution = .fillEqually
        for (index, name) in ["All", "Tutorials", "Spaces", "Makers"].enumerated() {
            let button = RoomUI.button(name) { [weak self] in self?.segment = index; self?.refresh() }
            button.accessibilityIdentifier = "search.category.\(index)"
            button.configuration?.baseBackgroundColor = index == segment ? .roomGreen : UIColor(white: 0.93, alpha: 1)
            button.configuration?.background.backgroundColor = index == segment ? .roomGreen : UIColor(white: 0.93, alpha: 1)
            button.configuration?.baseForegroundColor = index == segment ? .white : .label
            button.configuration?.background.cornerRadius = 12
            button.configuration?.titleTextAttributesTransformer = .init { attributes in var attributes = attributes; attributes.font = .systemFont(ofSize: 12); return attributes }
            button.accessibilityTraits = index == segment ? [.button, .selected] : .button
            categories.addArrangedSubview(button)
        }
        body.spacing = 10; add(categories); showSearchResults()
    }
    func showSearchResults() {
        body.arrangedSubviews.filter { $0.accessibilityIdentifier == "search.result" }.forEach { $0.removeFromSuperview() }
        let query = (fields["query"]?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filters = SearchFilters(preferences: coordinator.store.state.preferences)
        var examples = searchExamples.filter { (query.isEmpty || ($0.title + " weaving woven").lowercased().contains(query)) && filters.matches(level: $0.level, minutes: $0.minutes) }
        if coordinator.store.state.preferences["search.shortest"] == true { examples.sort { $0.minutes < $1.minutes } }
        let otherMatch = query.isEmpty || (segment == 2 ? "reading corner room space" : "nora lane maker").contains(query)
        let count = segment < 2 ? examples.count : (otherMatch ? 1 : 0)
        let filtersButton = action("", "@filters", icon: "slider.horizontal.3"); filtersButton.accessibilityLabel = AppLanguage.text("Filters")
        let sort = RoomUI.button("Sort", icon: "chevron.down") {}; sort.configuration?.baseForegroundColor = .label; sort.configuration?.imagePlacement = .trailing
        sort.menu = UIMenu(children: [UIAction(title: AppLanguage.text("Recommended")) { [weak self] _ in self?.setSearchSort(false) }, UIAction(title: AppLanguage.text("Shortest time")) { [weak self] _ in self?.setSearchSort(true) }]); sort.showsMenuAsPrimaryAction = true
        let meta = RoomUI.stack([RoomUI.label("\(count) results", size: 13, color: .secondaryLabel), sort, filtersButton], axis: .horizontal, spacing: 8)
        sort.widthAnchor.constraint(equalToConstant: 72).isActive = true; meta.alignment = .center; meta.accessibilityIdentifier = "search.result"; add(meta)
        if count == 0 {
            let empty = RoomUI.stack([RoomUI.label("No matches yet", size: 24, weight: .bold), RoomUI.label("Try a different keyword, skill level or time.", size: 15, color: .secondaryLabel)], spacing: 10)
            empty.accessibilityIdentifier = "search.result"; add(empty); return
        }
        if segment >= 2 {
            let result = segment == 2 ? artworkCard("space-reading", title: "Reading corner", subtitle: "A cozy space for slow mornings.", code: "S02") : row("Nora Lane", subtitle: "Maker · Home stylist · Teacher", icon: "person.crop.circle", code: "C05")
            result.accessibilityIdentifier = "search.result"; add(result); return
        }
        for example in examples {
            let cover = RoomUI.image(example.asset, ratio: 0.84, radius: 12); cover.widthAnchor.constraint(equalToConstant: 112).isActive = true
            let title = RoomUI.button(example.title) { [weak self] in
                guard let self else { return }
                if example.id == "D04" { self.act("D04") }
                else { self.coordinator.message(example.title, "A step-by-step tutorial is not available yet. You can save this idea for inspiration.") }
            }
            title.accessibilityIdentifier = "search.open.\(example.id)"; title.configuration?.baseForegroundColor = .label
            title.configuration?.contentInsets = .zero; title.contentHorizontalAlignment = .leading
            title.configuration?.titleTextAttributesTransformer = .init { attributes in var attributes = attributes; attributes.font = .systemFont(ofSize: 14, weight: .semibold); return attributes }
            let save = RoomUI.button("", icon: coordinator.store.state.saved.contains(example.id) ? "bookmark.fill" : "bookmark") { [weak self] in
                guard let self else { return }; self.coordinator.perform { try self.coordinator.store.toggleSaved(example.id) }; self.showSearchResults()
            }
            save.accessibilityIdentifier = "search.save.\(example.id)"; save.accessibilityLabel = AppLanguage.text("Save") + " " + AppLanguage.text(example.title); save.configuration?.baseForegroundColor = .label
            let heading = RoomUI.stack([title, save], axis: .horizontal, spacing: 0)
            let tags = RoomUI.stack(axis: .horizontal, spacing: 7)
            for (text, color) in [(SearchFilters.levels[example.level], example.level == 1 ? UIColor(red: 0.90, green: 0.94, blue: 0.89, alpha: 1) : UIColor(red: 0.91, green: 0.89, blue: 0.98, alpha: 1)), (example.minutes == 90 ? "90 min" : "\(example.minutes / 60) \(example.minutes == 60 ? "hour" : "hours")", UIColor(white: 0.94, alpha: 1))] {
                let badge = RoomUI.card(RoomUI.label(text, size: 10, color: .roomGreen), inset: 5); badge.backgroundColor = color; badge.layer.cornerRadius = 10; badge.setContentHuggingPriority(.required, for: .horizontal); tags.addArrangedSubview(badge)
            }
            tags.addArrangedSubview(UIView())
            let details = RoomUI.stack([heading, RoomUI.label(example.subtitle, size: 13, color: .secondaryLabel), tags], spacing: 4)
            let row = RoomUI.stack([cover, details], axis: .horizontal, spacing: 12); row.alignment = .center
            let card = RoomUI.card(row, inset: 6); card.accessibilityIdentifier = "search.result"; add(card)
        }
    }
    private func setSearchSort(_ shortest: Bool) {
        coordinator.perform { try coordinator.store.setPreference("search.shortest", value: shortest) }; showSearchResults()
    }
}
