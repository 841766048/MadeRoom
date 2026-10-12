import UIKit

enum RoomTabIcon {
    static let names = ["discover", "make", "spaces", "community", "profile"]
    static func image(at index: Int, selected: Bool = false) -> UIImage? {
        guard names.indices.contains(index) else { return nil }
        let name = "tab-" + names[index] + (selected ? "-selected" : "")
        return UIImage(named: name)?.withRenderingMode(.alwaysTemplate)
    }
}

/// Stable UIKit tab treatment matching the approved five-column design across iOS versions.
final class RoomTabController: UITabBarController {
    private let bar = UIView()
    private let stack = UIStackView()
    private var buttons: [UIButton] = []
    var onSelect: ((Int) -> Void)?
    override func viewDidLoad() {
        super.viewDidLoad()
        tabBar.isHidden = true
        bar.backgroundColor = .roomCream
        bar.layer.cornerRadius = 22
        stack.axis = .horizontal; stack.distribution = .fillEqually
        bar.addSubview(stack); view.addSubview(bar)
        for i in 0..<5 {
            var config = UIButton.Configuration.plain()
            config.image = RoomTabIcon.image(at: i)
            config.imagePlacement = .top; config.imagePadding = 4
            config.contentInsets = .zero
            config.title = AppLanguage.text(ScreenRoutes.tabs[i])
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                var attributes = attributes; attributes.font = .systemFont(ofSize: 10, weight: .medium); return attributes
            }
            let button = UIButton(configuration: config)
            button.titleLabel?.numberOfLines = 1
            button.titleLabel?.adjustsFontSizeToFitWidth = true
            button.titleLabel?.minimumScaleFactor = 0.8
            button.accessibilityIdentifier = "tab.\(ScreenRoutes.roots[i])"
            button.addAction(UIAction { [weak self] _ in self?.onSelect?(i) }, for: .touchUpInside)
            buttons.append(button); stack.addArrangedSubview(button)
        }
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews(); updateBar()
        bar.frame = CGRect(x: 10, y: view.bounds.height-view.safeAreaInsets.bottom-60, width: view.bounds.width-20, height: 58)
        stack.frame = bar.bounds
        view.bringSubviewToFront(bar)
    }
    func updateBar() {
        guard isViewLoaded else { return }
        tabBar.isHidden = true
        let nav = selectedViewController as? UINavigationController
        let hidden = (nav?.viewControllers.count ?? 1)>1
        bar.isHidden = hidden
        for (i, button) in buttons.enumerated() {
            button.configuration?.title = AppLanguage.text(ScreenRoutes.tabs[i])
            let selected = i == selectedIndex
            button.configuration?.image = RoomTabIcon.image(at: i, selected: selected)
            button.configuration?.baseForegroundColor = selected ? .roomGreen : UIColor(red:112/255,green:118/255,blue:122/255,alpha:1)
            button.accessibilityTraits = selected ? [.button, .selected] : [.button]
        }
        for case let navigation as UINavigationController in viewControllers ?? [] {
            let desired: CGFloat = navigation.viewControllers.count>1 ? 0 : 60
            if navigation.additionalSafeAreaInsets.bottom != desired { navigation.additionalSafeAreaInsets.bottom = desired }
        }
    }
}

/// One owner for navigation transitions, edge-swipe handling and tab visibility.
final class RoomNavigationController: UINavigationController, UINavigationControllerDelegate, UIGestureRecognizerDelegate {
    var onNavigationChanged: (() -> Void)?
    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        interactivePopGestureRecognizer?.delegate = self
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground(); appearance.backgroundColor = .roomCream
        appearance.shadowColor = .clear
        navigationBar.standardAppearance = appearance; navigationBar.scrollEdgeAppearance = appearance
        navigationBar.tintColor = .roomGreen
    }
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        setNavigationBarHidden(viewControllers.first === viewController, animated: animated)
        onNavigationChanged?()
    }
    func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        onNavigationChanged?()
    }
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1 && transitionCoordinator == nil
    }
}
