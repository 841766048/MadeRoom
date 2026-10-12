import UIKit

struct RoomDialogAction {
    enum Style { case `default`, cancel, destructive }
    let title: String
    let style: Style
    var handler: ((RoomDialogAction) -> Void)?
    init(title: String, style: Style, handler: ((RoomDialogAction) -> Void)? = nil) {
        self.title = title; self.style = style; self.handler = handler
    }
}

/// App-owned sheets, based on X11 / X13 and the DS01–DS02 controls.
/// System photo and sharing controllers remain system-owned.
final class RoomDialogController: UIViewController {
    enum Style { case alert, actionSheet }
    private let bodyText: String?
    private let style: Style
    private(set) var actions: [RoomDialogAction] = []
    private let panel = UIView()
    init(title: String?, message: String?, preferredStyle: Style) {
        bodyText = message; style = preferredStyle
        super.init(nibName: nil, bundle: nil)
        self.title = title
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func addAction(_ action: RoomDialogAction) { actions.append(action) }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.accessibilityViewIsModal = true
        view.accessibilityIdentifier = "dialog"
        view.backgroundColor = UIColor.black.withAlphaComponent(0.32)
        let backdrop = UIButton(type: .custom)
        backdrop.accessibilityLabel = AppLanguage.text("Dismiss dialog")
        backdrop.addAction(UIAction { [weak self] _ in self?.cancel() }, for: .touchUpInside)
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backdrop)
        panel.backgroundColor = .white
        panel.layer.cornerRadius = 24
        panel.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        panel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(panel)
        let swipe = UISwipeGestureRecognizer(target: self, action: #selector(cancel))
        swipe.direction = .down; panel.addGestureRecognizer(swipe)
        let handle = UIView(); handle.backgroundColor = UIColor(white: 0.57, alpha: 1); handle.layer.cornerRadius = 2
        handle.translatesAutoresizingMaskIntoConstraints = false; panel.addSubview(handle)
        let scroll = UIScrollView(); scroll.translatesAutoresizingMaskIntoConstraints = false; panel.addSubview(scroll)
        let stack = UIStackView(); stack.axis = .vertical; stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false; scroll.addSubview(stack)
        let destructive = actions.contains { $0.style == .destructive }
        if destructive && style == .alert && (title?.hasPrefix("Delete") ?? false) {
            let icon = UIImageView(image: UIImage(systemName: "trash.fill"))
            icon.tintColor = .systemRed; icon.contentMode = .scaleAspectFit
            icon.heightAnchor.constraint(equalToConstant: 32).isActive = true
            stack.addArrangedSubview(icon)
        }
        let heading = label(title ?? "", size: 23, weight: .bold)
        heading.accessibilityIdentifier = "dialog.title"; heading.accessibilityTraits = .header
        stack.addArrangedSubview(heading)
        if let bodyText, !bodyText.isEmpty {
            let body = label(bodyText, size: 16, weight: .regular)
            body.textColor = UIColor(white: 0.30, alpha: 1)
            stack.addArrangedSubview(body)
            stack.setCustomSpacing(28, after: body)
        }
        let buttons = UIStackView(); buttons.axis = style == .alert && actions.count == 2 ? .horizontal : .vertical
        buttons.spacing = 10; buttons.distribution = .fillEqually
        for action in actions {
            var config = UIButton.Configuration.filled()
            config.title = AppLanguage.text(action.title)
            config.baseBackgroundColor = action.style == .cancel ? UIColor(white: 0.93, alpha: 1) : action.style == .destructive ? .systemRed : .roomGreen
            config.baseForegroundColor = action.style == .cancel ? .black : .white
            config.background.cornerRadius = 16
            config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 12, bottom: 14, trailing: 12)
            if style == .actionSheet && action.style == .default {
                config.baseBackgroundColor = UIColor(white: 0.96, alpha: 1)
                config.baseForegroundColor = .black
            }
            let button = UIButton(configuration: config)
            button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
            button.titleLabel?.adjustsFontForContentSizeCategory = true
            button.titleLabel?.numberOfLines = 0
            button.accessibilityIdentifier = "dialog.action." + action.title
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 52).isActive = true
            button.addAction(UIAction { [weak self] _ in
                self?.dismiss(animated: !UIAccessibility.isReduceMotionEnabled) { action.handler?(action) }
            }, for: .touchUpInside)
            buttons.addArrangedSubview(button)
        }
        stack.addArrangedSubview(buttons)
        let preferredHeight = scroll.heightAnchor.constraint(equalTo: stack.heightAnchor)
        preferredHeight.priority = .defaultHigh
        NSLayoutConstraint.activate([
            backdrop.leadingAnchor.constraint(equalTo: view.leadingAnchor), backdrop.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backdrop.topAnchor.constraint(equalTo: view.topAnchor), backdrop.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            panel.leadingAnchor.constraint(equalTo: view.leadingAnchor), panel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            panel.bottomAnchor.constraint(equalTo: view.bottomAnchor), panel.topAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            handle.topAnchor.constraint(equalTo: panel.topAnchor, constant: 12), handle.centerXAnchor.constraint(equalTo: panel.centerXAnchor),
            handle.widthAnchor.constraint(equalToConstant: 32), handle.heightAnchor.constraint(equalToConstant: 4),
            scroll.topAnchor.constraint(equalTo: handle.bottomAnchor, constant: 22), scroll.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 18),
            scroll.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -18), scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -18),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor), stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor), stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor), preferredHeight
        ])
    }
    private func label(_ text: String, size: CGFloat, weight: UIFont.Weight) -> UILabel {
        let label = UILabel(); label.text = AppLanguage.text(text); label.numberOfLines = 0; label.textAlignment = .center
        label.font = UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: size, weight: weight))
        label.adjustsFontForContentSizeCategory = true; return label
    }
    @objc private func cancel() {
        guard let action = actions.first(where: { $0.style == .cancel }) else { return }
        dismiss(animated: !UIAccessibility.isReduceMotionEnabled) { action.handler?(action) }
    }
    override func accessibilityPerformEscape() -> Bool { cancel(); return actions.contains { $0.style == .cancel } }
}
