import UIKit

/// Pixso Network Loading: 144 × 148 pt, 24 pt corners, 86 pt illustration.
final class RequestLoadingView: UIView {
    private let card = UIView()
    private let illustration = YarnLoadingView()
    private let label = UILabel()
    private var pending: DispatchWorkItem?
    private(set) var isWaiting = false

    init() {
        super.init(frame: .zero)
        accessibilityIdentifier = "request.loading"
        backgroundColor = UIColor(red: 36/255, green: 57/255, blue: 45/255, alpha: 0.08)
        card.backgroundColor = UIColor(red: 1, green: 254/255, blue: 250/255, alpha: 1)
        card.layer.cornerRadius = 24
        label.text = "Loading…"
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = UIColor(red: 64/255, green: 100/255, blue: 71/255, alpha: 1)
        label.textAlignment = .center
        addSubview(card); card.addSubview(illustration); card.addSubview(label)
        for v in [card, illustration, label] { v.translatesAutoresizingMaskIntoConstraints = false }
        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: centerXAnchor), card.centerYAnchor.constraint(equalTo: centerYAnchor),
            card.widthAnchor.constraint(equalToConstant: 144), card.heightAnchor.constraint(equalToConstant: 148),
            illustration.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            illustration.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            illustration.widthAnchor.constraint(equalToConstant: 86), illustration.heightAnchor.constraint(equalToConstant: 86),
            label.topAnchor.constraint(equalTo: card.topAnchor, constant: 111),
            label.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12), label.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12)
        ])
        isAccessibilityElement = true; accessibilityLabel = "Loading"; accessibilityViewIsModal = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func show(in host: UIView, message: String = "Loading…", delay: TimeInterval = 0.25) {
        dismiss()
        isWaiting = true; label.text = message; accessibilityLabel = message
        let work = DispatchWorkItem { [weak self, weak host] in
            guard let self, let host, self.isWaiting else { return }
            host.endEditing(true)
            host.addSubview(self); self.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([self.leadingAnchor.constraint(equalTo: host.leadingAnchor), self.trailingAnchor.constraint(equalTo: host.trailingAnchor), self.topAnchor.constraint(equalTo: host.topAnchor), self.bottomAnchor.constraint(equalTo: host.bottomAnchor)])
            UIAccessibility.post(notification: .layoutChanged, argument: self)
        }
        pending = work; DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }
    func dismiss() {
        isWaiting = false; pending?.cancel(); pending = nil; removeFromSuperview()
    }
}

final class YarnLoadingView: UIView {
    private let ring = CAShapeLayer()
    private let yarn = UIView()
    private let animates: Bool
    init(frame: CGRect = .zero, showsRing: Bool = true, animates: Bool = true) {
        self.animates = animates
        super.init(frame: frame)
        isUserInteractionEnabled = false
        let track = CAShapeLayer()
        track.path = UIBezierPath(arcCenter: CGPoint(x: 43, y: 43), radius: 38, startAngle: 0, endAngle: .pi * 2, clockwise: true).cgPath
        track.fillColor = UIColor.clear.cgColor; track.strokeColor = color("E1E7D4").cgColor; track.lineWidth = 3
        if showsRing { layer.addSublayer(track) }
        ring.frame = CGRect(x: 0, y: 0, width: 86, height: 86)
        ring.path = UIBezierPath(arcCenter: CGPoint(x: 43, y: 43), radius: 38, startAngle: -.pi / 2, endAngle: -.pi / 12, clockwise: true).cgPath
        ring.fillColor = UIColor.clear.cgColor; ring.strokeColor = color("668961").cgColor; ring.lineWidth = 3; ring.lineCap = .round
        if showsRing { layer.addSublayer(ring) }
        yarn.frame = CGRect(x: 0, y: 0, width: 86, height: 86); addSubview(yarn)
        buildYarn()
        NotificationCenter.default.addObserver(self, selector: #selector(updateMotion), name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateMotion), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func didMoveToWindow() { super.didMoveToWindow(); updateMotion() }
    @objc private func updateMotion() {
        ring.removeAllAnimations(); yarn.layer.removeAllAnimations()
        guard animates, window != nil, !UIAccessibility.isReduceMotionEnabled else { return }
        let spin = CABasicAnimation(keyPath: "transform.rotation.z"); spin.fromValue = 0; spin.toValue = Double.pi * 2; spin.duration = 1.2; spin.repeatCount = .infinity
        ring.add(spin, forKey: "rotation")
        let breathe = CABasicAnimation(keyPath: "transform.scale"); breathe.fromValue = 0.98; breathe.toValue = 1; breathe.duration = 1.2; breathe.autoreverses = true; breathe.repeatCount = .infinity; breathe.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        yarn.layer.add(breathe, forKey: "breathing")
    }
    private func color(_ hex: String) -> UIColor {
        let n = UInt32(hex, radix: 16)!
        return UIColor(red: CGFloat((n >> 16) & 255)/255, green: CGFloat((n >> 8) & 255)/255, blue: CGFloat(n & 255)/255, alpha: 1)
    }
    private func shape(_ path: UIBezierPath, fill: String? = nil, stroke: String? = nil, width: CGFloat = 4) {
        path.apply(CGAffineTransform(scaleX: 86/264, y: 86/264))
        let layer = CAShapeLayer(); layer.path = path.cgPath; layer.fillColor = fill.map { color($0).cgColor } ?? UIColor.clear.cgColor
        layer.strokeColor = stroke.map { color($0).cgColor }; layer.lineWidth = width * 86/264; layer.lineCap = .round
        yarn.layer.addSublayer(layer)
    }
    private func curve(_ points: [CGFloat], stroke: String, width: CGFloat = 4) {
        let p = UIBezierPath(); p.move(to: CGPoint(x: points[0], y: points[1]))
        for i in stride(from: 2, to: points.count, by: 4) { p.addQuadCurve(to: CGPoint(x: points[i+2], y: points[i+3]), controlPoint: CGPoint(x: points[i], y: points[i+1])) }
        shape(p, stroke: stroke, width: width)
    }
    private func buildYarn() {
        shape(UIBezierPath(ovalIn: CGRect(x: 71, y: 210, width: 122, height: 16)), fill: "E7E4D8")
        curve([81,169,58,199,82,205,111,210,113,193], stroke: "91AA75", width: 5)
        shape(UIBezierPath(ovalIn: CGRect(x: 59, y: 54, width: 146, height: 146)), fill: "BDD29C")
        for p: [CGFloat] in [[72,90,132,41,186,103],[64,112,126,66,196,129],[63,137,125,88,190,158],[74,165,117,129,172,181]] { curve(p, stroke: "9DBB7F") }
        curve([91,64,91,109,175,185], stroke: "D1E1B5"); curve([113,56,109,109,192,163], stroke: "D1E1B5")
        for x in [105,147] { shape(UIBezierPath(ovalIn: CGRect(x: x, y: 118, width: 10, height: 14)), fill: "304835") }
        curve([120,142,132,153,144,142], stroke: "304835")
        for x in [90,157] { shape(UIBezierPath(ovalIn: CGRect(x: x, y: 136, width: 16, height: 8)), fill: "D9B69A") }
        for (v,c): ([CGFloat],String) in [([129,56,122,32,144,28,151,44,129,56],"62855D"),([130,57,153,35,166,47,161,63,130,57],"8FAB70")] {
            let p = UIBezierPath(); p.move(to: CGPoint(x:v[0],y:v[1])); for i in stride(from:2,to:v.count,by:4) { p.addQuadCurve(to:CGPoint(x:v[i+2],y:v[i+3]),controlPoint:CGPoint(x:v[i],y:v[i+1])) }; p.close(); shape(p,fill:c)
        }
        let hook = UIBezierPath(); hook.move(to: CGPoint(x:188,y:161)); hook.addLine(to: CGPoint(x:215,y:88)); hook.addQuadCurve(to:CGPoint(x:229,y:84),controlPoint:CGPoint(x:221,y:76)); hook.addQuadCurve(to:CGPoint(x:225,y:95),controlPoint:CGPoint(x:235,y:90)); shape(hook,stroke:"B18C63",width:7)
    }
}
