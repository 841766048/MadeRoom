import UIKit
import CoreText

enum AuthStyle {
    static let cream = UIColor(red: 1, green: 253/255, blue: 248/255, alpha: 1)
    static let green = UIColor(red: 49/255, green: 94/255, blue: 73/255, alpha: 1)
    static let ink = UIColor(red: 23/255, green: 43/255, blue: 40/255, alpha: 1)
    static let muted = UIColor(red: 105/255, green: 119/255, blue: 111/255, alpha: 1)
    static let disabled = UIColor(red: 169/255, green: 186/255, blue: 173/255, alpha: 1)
    static func text(_ zh: String, _ en: String) -> String { AppLanguage.isChinese ? zh : en }
    private static let registerFonts: Void = {
        for style in ["Regular","Medium","Bold"] {
            if let url = Bundle.main.url(forResource: "SourceHanSansCN-\(style)_1", withExtension: "otf", subdirectory: "AuthFonts") {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }()
    static func font(_ size: CGFloat, bold: Bool = false) -> UIFont {
        _ = registerFonts
        let base = UIFont(name: "SourceHanSansCN-\(bold ? "Bold" : "Regular")", size: size) ?? .systemFont(ofSize: size, weight: bold ? .bold : .regular)
        return UIFontMetrics(forTextStyle: .body).scaledFont(for: base)
    }
    static func label(_ text: String, size: CGFloat = 16, bold: Bool = false, center: Bool = false) -> UILabel {
        let l = AuthInsetLabel(); l.numberOfLines = 0; l.font = font(size, bold: bold); l.adjustsFontForContentSizeCategory = true
        l.textColor = bold ? ink : muted; l.textAlignment = center ? .center : .left
        let p = NSMutableParagraphStyle(); p.alignment = l.textAlignment
        p.minimumLineHeight = max(ceil(l.font.lineHeight), size > 20 ? 36 : 24)
        l.attributedText = NSAttributedString(string: text, attributes: [.font:l.font as Any, .foregroundColor:l.textColor as Any, .paragraphStyle:p])
        l.setContentCompressionResistancePriority(.required, for: .vertical)
        return l
    }
    static func button(_ title: String, id: String, primary: Bool = true, action: @escaping () -> Void) -> UIButton {
        let b = UIButton(type: .system); b.setTitle(title, for: .normal); b.titleLabel?.font = font(primary ? 17 : 15)
        b.titleLabel?.numberOfLines = 0; b.titleLabel?.textAlignment = .center
        b.contentEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        b.titleLabel?.setContentCompressionResistancePriority(.required, for: .vertical)
        b.setContentCompressionResistancePriority(.required, for: .vertical)
        b.setTitleColor(primary ? .white : green, for: .normal)
        b.backgroundColor = primary ? green : .clear; b.layer.cornerRadius = 12
        b.heightAnchor.constraint(greaterThanOrEqualToConstant: primary ? 52 : 44).isActive = true
        b.accessibilityIdentifier = id; b.addAction(UIAction { _ in action() }, for: .touchUpInside); return b
    }
    static func art(_ name: String) -> UIImageView {
        let v = EditorialImageView(asset: name); v.contentMode = .scaleAspectFit; v.clipsToBounds = true
        v.isAccessibilityElement = false; return v
    }
}

/// Only the illustration is raster; UIKit draws the brand and continuous edge fades.
final class AuthHeroView: UIView {
    private let imageView = AuthStyle.art("auth-room")
    private let topFade = CAGradientLayer()
    private let bottomFade = CAGradientLayer()
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(imageView); imageView.translatesAutoresizingMaskIntoConstraints = false; imageView.contentMode = .scaleAspectFill
        NSLayoutConstraint.activate([imageView.leadingAnchor.constraint(equalTo: leadingAnchor), imageView.trailingAnchor.constraint(equalTo: trailingAnchor), imageView.topAnchor.constraint(equalTo: topAnchor, constant: 80), imageView.bottomAnchor.constraint(equalTo: bottomAnchor)])
        topFade.colors = [AuthStyle.cream.cgColor,AuthStyle.cream.withAlphaComponent(0).cgColor]
        bottomFade.colors = [AuthStyle.cream.withAlphaComponent(0).cgColor,AuthStyle.cream.cgColor]
        imageView.layer.addSublayer(topFade); imageView.layer.addSublayer(bottomFade)
        let brand = AuthStyle.label("Made Room", size: 28, bold: true, center: true)
        let subtitle = AuthStyle.label(AuthStyle.text("手作 · 空间 · 同好", "Craft · Home · People"), size: 14, center: true)
        for v in [brand,subtitle] { addSubview(v); v.translatesAutoresizingMaskIntoConstraints = false }
        NSLayoutConstraint.activate([brand.topAnchor.constraint(equalTo: topAnchor),brand.leadingAnchor.constraint(equalTo: leadingAnchor,constant:24),brand.trailingAnchor.constraint(equalTo: trailingAnchor,constant:-24),subtitle.topAnchor.constraint(equalTo: brand.bottomAnchor),subtitle.centerXAnchor.constraint(equalTo: centerXAnchor)])
    }
    required init?(coder: NSCoder) { fatalError("init(frame:)") }
    override func layoutSubviews() {
        super.layoutSubviews(); CATransaction.begin(); CATransaction.setDisableActions(true)
        topFade.frame = CGRect(x:0,y:0,width:imageView.bounds.width,height:40)
        bottomFade.frame = CGRect(x:0,y:max(0,imageView.bounds.height-44),width:imageView.bounds.width,height:44)
        CATransaction.commit()
    }
}

final class AuthShieldView: UIView {
    override init(frame: CGRect) { super.init(frame: frame); isOpaque = false; backgroundColor = .clear }
    required init?(coder: NSCoder) { fatalError("init(frame:)") }
    override func draw(_ rect: CGRect) {
        guard let c = UIGraphicsGetCurrentContext() else { return }
        c.saveGState();c.translateBy(x:(bounds.width-48)/2,y:0)
        let shield = UIBezierPath();shield.move(to:CGPoint(x:24,y:3));shield.addLine(to:CGPoint(x:43,y:11));shield.addLine(to:CGPoint(x:43,y:25));shield.addCurve(to:CGPoint(x:24,y:49),controlPoint1:CGPoint(x:43,y:37),controlPoint2:CGPoint(x:35,y:44));shield.addCurve(to:CGPoint(x:5,y:25),controlPoint1:CGPoint(x:13,y:44),controlPoint2:CGPoint(x:5,y:37));shield.addLine(to:CGPoint(x:5,y:11));shield.close()
        UIColor(red:231/255,green:238/255,blue:229/255,alpha:1).setFill();shield.fill();AuthStyle.green.setStroke();shield.lineWidth=2.5;shield.stroke()
        let leaf = UIBezierPath();leaf.move(to:CGPoint(x:24,y:35));leaf.addLine(to:CGPoint(x:24,y:22));leaf.move(to:CGPoint(x:24,y:29));leaf.addCurve(to:CGPoint(x:16,y:17),controlPoint1:CGPoint(x:14,y:29),controlPoint2:CGPoint(x:13,y:21));leaf.addCurve(to:CGPoint(x:24,y:29),controlPoint1:CGPoint(x:23,y:17),controlPoint2:CGPoint(x:26,y:22));leaf.move(to:CGPoint(x:24,y:25));leaf.addCurve(to:CGPoint(x:34,y:16),controlPoint1:CGPoint(x:24,y:18),controlPoint2:CGPoint(x:29,y:14));leaf.addCurve(to:CGPoint(x:24,y:25),controlPoint1:CGPoint(x:34,y:22),controlPoint2:CGPoint(x:30,y:26));AuthStyle.green.setFill();leaf.fill();leaf.lineWidth=1.5;leaf.stroke();c.restoreGState()
    }
}

/// Include ascender/descender breathing room in both measurement and drawing.
final class AuthInsetLabel: UILabel {
    private let padding = UIEdgeInsets(top: 3, left: 0, bottom: 3, right: 0)
    override func textRect(forBounds bounds: CGRect, limitedToNumberOfLines lines: Int) -> CGRect {
        let measured = super.textRect(forBounds: bounds.inset(by: padding), limitedToNumberOfLines: lines)
        return measured.inset(by: UIEdgeInsets(top: -padding.top, left: 0, bottom: -padding.bottom, right: 0))
    }
    override func drawText(in rect: CGRect) { super.drawText(in: rect.inset(by: padding)) }
}

final class AuthAgreementButton: UIButton {
    init(action: @escaping () -> Void) {
        super.init(frame: .zero)
        accessibilityIdentifier = "auth.agreement"
        accessibilityLabel = AuthStyle.text("我已阅读并同意用户协议和隐私政策", "I agree to the Terms of use and Privacy policy")
        accessibilityHint = AuthStyle.text("轻点切换是否同意", "Double tap to toggle agreement")
        contentHorizontalAlignment = .leading
        heightAnchor.constraint(greaterThanOrEqualToConstant: 52).isActive = true
        configurationUpdateHandler = { button in
            var config = UIButton.Configuration.plain()
            config.title = AuthStyle.text("我已阅读并同意", "I have read and agree")
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                var attributes = attributes; attributes.font = AuthStyle.font(15); return attributes
            }
            config.image = UIImage(systemName: button.isSelected ? "checkmark.square.fill" : "square", withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .regular))
            config.imagePadding = 12
            config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
            config.baseForegroundColor = button.isSelected ? AuthStyle.green : AuthStyle.muted
            config.background.backgroundColor = button.isSelected ? AuthStyle.green.withAlphaComponent(0.08) : .clear
            config.background.cornerRadius = 12
            button.configuration = config
            button.accessibilityValue = button.isSelected ? AuthStyle.text("已同意", "Agreed") : AuthStyle.text("未同意", "Not agreed")
        }
        addAction(UIAction { _ in action() }, for: .touchUpInside)
        setNeedsUpdateConfiguration()
    }
    required init?(coder: NSCoder) { fatalError("init(action:)") }
}
