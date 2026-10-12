import UIKit

struct SearchFilters: Equatable {
    static let levels = ["All", "Beginner", "Intermediate", "Advanced"]
    static let times = ["Any", "Under 2 hours", "2–4 hours", "Over 4 hours"]
    var level = 0
    var time = 0
    init(preferences: [String: Bool]) {
        level = (1..<Self.levels.count).first { preferences["search.level.\($0)"] == true } ?? 0
        time = (1..<Self.times.count).first { preferences["search.time.\($0)"] == true } ?? 0
    }
    func matches(level: Int, minutes: Int) -> Bool {
        (self.level == 0 || self.level == level) && (time == 0 || (time == 1 && minutes < 120) || (time == 2 && minutes >= 120 && minutes <= 240) || (time == 3 && minutes > 240))
    }
    func write(to preferences: inout [String: Bool]) {
        for i in 0..<Self.levels.count { preferences["search.level.\(i)"] = i == level }
        for i in 0..<Self.times.count { preferences["search.time.\(i)"] = i == time }
    }
}

/// D02: a draft selection is committed only by Apply filters.
final class SearchFilterController: UIViewController {
    private var draft: SearchFilters
    private let apply: (SearchFilters) -> Void
    private var groups: [[UIButton]] = []
    init(filters: SearchFilters, apply: @escaping (SearchFilters) -> Void) {
        draft = filters; self.apply = apply
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.custom(identifier: .init("filters")) { _ in 340 }, .large()]
            sheet.prefersGrabberVisible = true; sheet.preferredCornerRadius = 28
            sheet.prefersScrollingExpandsWhenScrolledToEdge = true
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad(); view.backgroundColor = .white; view.accessibilityIdentifier = "search.filters"
        let stack = RoomUI.stack(spacing: 22); stack.translatesAutoresizingMaskIntoConstraints = false
        let scroll = UIScrollView(); scroll.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(scroll); scroll.addSubview(stack)
        let title = RoomUI.label("Filters", size: 20, weight: .bold); title.accessibilityTraits = .header; stack.addArrangedSubview(title)
        for (groupIndex, pair) in [("Skill level", SearchFilters.levels), ("Time needed", SearchFilters.times)].enumerated() {
            let chips = RoomUI.stack(axis: .horizontal, spacing: 7); chips.distribution = .fillProportionally
            var buttons: [UIButton] = []
            for (index, name) in pair.1.enumerated() {
                let button = UIButton(type: .system)
                button.accessibilityIdentifier = "filter.\(groupIndex).\(index)"
                button.accessibilityLabel = AppLanguage.text(name)
                button.heightAnchor.constraint(greaterThanOrEqualToConstant: 38).isActive = true
                button.addAction(UIAction { [weak self] _ in
                    guard let self else { return }
                    if groupIndex == 0 { self.draft.level = index } else { self.draft.time = index }
                    self.updateSelection()
                }, for: .touchUpInside)
                chips.addArrangedSubview(button); buttons.append(button)
            }
            groups.append(buttons)
            stack.addArrangedSubview(RoomUI.stack([RoomUI.label(pair.0, size: 14, weight: .semibold), chips], spacing: 10))
        }
        let applyButton = RoomUI.button("Apply filters", primary: true) { [weak self] in
            guard let self else { return }; let value = self.draft
            self.dismiss(animated: !UIAccessibility.isReduceMotionEnabled) { self.apply(value) }
        }
        applyButton.accessibilityIdentifier = "filter.apply"
        applyButton.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(applyButton)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18), scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            scroll.topAnchor.constraint(equalTo: view.topAnchor, constant: 32), scroll.bottomAnchor.constraint(equalTo: applyButton.topAnchor, constant: -20),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor), stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor), stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
            applyButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18), applyButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            applyButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16), applyButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 46)
        ])
        updateSelection()
    }
    private func updateSelection() {
        for (group, buttons) in groups.enumerated() {
            for (index, button) in buttons.enumerated() {
                let selected = index == (group == 0 ? draft.level : draft.time)
                var config = UIButton.Configuration.filled()
                config.title = AppLanguage.text((group == 0 ? SearchFilters.levels : SearchFilters.times)[index])
                config.baseBackgroundColor = selected ? .roomGreen : UIColor(white: 0.95, alpha: 1)
                config.baseForegroundColor = selected ? .white : .label
                config.background.cornerRadius = 12
                config.contentInsets = .init(top: 8, leading: 7, bottom: 8, trailing: 7)
                config.image = selected ? UIImage(systemName: "checkmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)) : nil
                config.imagePadding = 4
                config.titleTextAttributesTransformer = .init { attributes in var attributes = attributes; attributes.font = .systemFont(ofSize: 11, weight: selected ? .semibold : .regular); return attributes }
                button.configuration = config; button.accessibilityTraits = selected ? [.button, .selected] : .button
                button.titleLabel?.numberOfLines = 2
            }
        }
    }
}
