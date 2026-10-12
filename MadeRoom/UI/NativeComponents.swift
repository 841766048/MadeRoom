import UIKit

enum RoomUI {
    static func label(_ text: String, size: CGFloat = 16, weight: UIFont.Weight = .regular, color: UIColor = .label) -> UILabel {
        let v = UILabel(); v.text = AppLanguage.text(text); v.numberOfLines = 0; v.textColor = color
        let base = UIFont.systemFont(ofSize:size,weight:weight)
        v.font = UIFontMetrics(forTextStyle:size>=24 ? .title2 : .body).scaledFont(for:base)
        v.adjustsFontForContentSizeCategory = true; return v
    }
    static func stack(_ views: [UIView] = [], axis: NSLayoutConstraint.Axis = .vertical, spacing: CGFloat = 12) -> UIStackView {
        let v = UIStackView(arrangedSubviews:views); v.axis = axis; v.spacing = spacing; return v
    }
    static func image(_ asset: String, ratio: CGFloat, radius: CGFloat = 16) -> UIImageView {
        let v = EditorialImageView(asset: asset); v.contentMode = .scaleAspectFill; v.clipsToBounds = true; v.layer.cornerRadius = radius
        v.translatesAutoresizingMaskIntoConstraints = false
        v.heightAnchor.constraint(equalTo:v.widthAnchor,multiplier:ratio).isActive = true
        v.isAccessibilityElement = true; v.accessibilityLabel = asset.replacingOccurrences(of:"-",with:" "); return v
    }
    static func button(_ title: String, icon: String? = nil, primary: Bool = false, action: @escaping ()->Void) -> UIButton {
        var config = primary ? UIButton.Configuration.filled() : UIButton.Configuration.plain()
        config.title = AppLanguage.text(title); config.baseBackgroundColor = .roomGreen; config.baseForegroundColor = primary ? .white : .roomGreen
        config.cornerStyle = .medium; config.imagePadding = 5; config.contentInsets = NSDirectionalEdgeInsets(top:12,leading:6,bottom:12,trailing:6)
        if let icon { config.image = UIImage(systemName:icon,withConfiguration:UIImage.SymbolConfiguration(pointSize:17,weight:.regular)) }
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { a in var a=a;a.font = .systemFont(ofSize:15,weight:.medium);return a }
        let v = UIButton(configuration:config);v.titleLabel?.numberOfLines = 0
        v.heightAnchor.constraint(greaterThanOrEqualToConstant:44).isActive = true
        if title.isEmpty { v.widthAnchor.constraint(equalToConstant:44).isActive = true }
        v.addAction(UIAction { _ in action() },for:.touchUpInside);return v
    }
    static func card(_ content: UIView, inset: CGFloat = 16) -> UIView {
        let v = UIView();v.backgroundColor = .white;v.layer.cornerRadius = 18
        content.translatesAutoresizingMaskIntoConstraints = false;v.addSubview(content)
        NSLayoutConstraint.activate([content.leadingAnchor.constraint(equalTo:v.leadingAnchor,constant:inset),content.trailingAnchor.constraint(equalTo:v.trailingAnchor,constant:-inset),content.topAnchor.constraint(equalTo:v.topAnchor,constant:inset),content.bottomAnchor.constraint(equalTo:v.bottomAnchor,constant:-inset)])
        return v
    }
    static func divider() -> UIView { let v=UIView();v.backgroundColor = .separator;v.heightAnchor.constraint(equalToConstant:0.5).isActive=true;return v }
}
