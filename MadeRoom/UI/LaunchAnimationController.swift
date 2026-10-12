import UIKit

/// Native rendition of Pixso's four launch frames; never owns authentication decisions.
final class LaunchAnimationController: UIViewController {
    private let canvas = UIView()
    private let mascot = YarnLoadingView(showsRing: false, animates: false)
    private let brand = UILabel()
    private let tagline = UILabel()
    private let thread = CAShapeLayer()
    private var started = false
    private(set) var finished = false
    var onFinish: (() -> Void)?
    private let reducedMotion: () -> Bool
    init(reducedMotion: @escaping () -> Bool = { UIAccessibility.isReduceMotionEnabled }) {
        self.reducedMotion = reducedMotion
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var prefersStatusBarHidden: Bool { true }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.accessibilityIdentifier = "launch.animation"
        view.backgroundColor = UIColor(red: 250/255, green: 248/255, blue: 243/255, alpha: 1)
        view.clipsToBounds = true
        canvas.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(canvas)
        NSLayoutConstraint.activate([canvas.widthAnchor.constraint(equalToConstant: 393), canvas.heightAnchor.constraint(equalToConstant: 852), canvas.centerXAnchor.constraint(equalTo: view.centerXAnchor), canvas.centerYAnchor.constraint(equalTo: view.centerYAnchor)])
        mascot.translatesAutoresizingMaskIntoConstraints = false; canvas.addSubview(mascot)
        NSLayoutConstraint.activate([mascot.widthAnchor.constraint(equalToConstant: 86), mascot.heightAnchor.constraint(equalToConstant: 86), mascot.centerXAnchor.constraint(equalTo: canvas.leadingAnchor, constant: 196.5), mascot.centerYAnchor.constraint(equalTo: canvas.topAnchor, constant: 360)])
        for (label, text, top, size) in [(brand, "Made Room", 455.0, 34.0), (tagline, "Make a little room for you.", 510.0, 15.0)] {
            label.text = text; label.textAlignment = .center
            label.font = .systemFont(ofSize: size, weight: label === brand ? .bold : .regular)
            label.textColor = label === brand ? UIColor(red: 36/255, green: 57/255, blue: 45/255, alpha: 1) : UIColor(red: 121/255, green: 129/255, blue: 118/255, alpha: 1)
            label.translatesAutoresizingMaskIntoConstraints = false; canvas.addSubview(label)
            NSLayoutConstraint.activate([label.leadingAnchor.constraint(equalTo: canvas.leadingAnchor, constant: 24), label.trailingAnchor.constraint(equalTo: canvas.trailingAnchor, constant: -24), label.topAnchor.constraint(equalTo: canvas.topAnchor, constant: top), label.heightAnchor.constraint(equalToConstant: size * 1.45)])
        }
        let path = UIBezierPath(); path.move(to: CGPoint(x: 180, y: 437))
        path.addCurve(to: CGPoint(x: 154, y: 527), controlPoint1: CGPoint(x: 90, y: 467), controlPoint2: CGPoint(x: 250, y: 492))
        path.addQuadCurve(to: CGPoint(x: 80, y: 562), controlPoint: CGPoint(x: 105, y: 552))
        thread.path = path.cgPath; thread.strokeColor = UIColor(red:145/255,green:170/255,blue:117/255,alpha:0.5).cgColor
        thread.fillColor = UIColor.clear.cgColor; thread.lineWidth = 3; thread.lineCap = .round; thread.opacity = 0
        canvas.layer.addSublayer(thread)
        NotificationCenter.default.addObserver(self, selector: #selector(interrupted), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(interrupted), name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
        if reducedMotion() { setFinalPose() }
        else { pose(size: 560, offset: 450); brand.alpha = 0; tagline.alpha = 0 }
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let scale = min(view.bounds.width / 393, view.bounds.height / 852)
        canvas.transform = CGAffineTransform(scaleX: scale, y: scale)
    }
    override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); play() }
    private func pose(size: CGFloat, offset: CGFloat, angle: CGFloat = 0) {
        mascot.transform = CGAffineTransform(translationX: 0, y: offset).rotated(by: angle).scaledBy(x: size/86, y: size/86)
    }
    func setFinalPose() {
        pose(size: 156, offset: 0); brand.alpha = 1; tagline.alpha = 1; thread.opacity = 0
    }
    private func play() {
        guard !started, !finished else { return }; started = true
        view.layoutIfNeeded()
        if reducedMotion() {
            setFinalPose(); canvas.alpha = 0
            UIView.animate(withDuration: 0.15, animations: { self.canvas.alpha = 1 }) { [weak self] _ in self?.finish() }
            return
        }
        pose(size: 560, offset: 450); brand.alpha = 0; tagline.alpha = 0
        UIView.animateKeyframes(withDuration: 1.6, delay: 0, options: [.calculationModeCubic, .beginFromCurrentState], animations: {
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.28125) { self.pose(size: 480, offset: 165, angle: -.pi/30) }
            UIView.addKeyframe(withRelativeStartTime: 0.28125, relativeDuration: 0.21875) { self.pose(size: 480, offset: 165, angle: 0) }
            UIView.addKeyframe(withRelativeStartTime: 0.5, relativeDuration: 0.25) { self.pose(size: 190, offset: 21) }
            UIView.addKeyframe(withRelativeStartTime: 0.75, relativeDuration: 0.25) { self.pose(size: 156, offset: 0); self.brand.alpha = 1; self.tagline.alpha = 1 }
        }) { [weak self] _ in self?.finish() }
        let reveal = CAKeyframeAnimation(keyPath: "opacity"); reveal.values = [0,0,0.5,0]; reveal.keyTimes = [0,0.5,0.75,1]; reveal.duration = 1.6
        thread.add(reveal, forKey: "threadReveal")
    }
    @objc private func interrupted() { finish() }
    func finish() {
        guard !finished else { return }; finished = true
        canvas.layer.removeAllAnimations(); mascot.layer.removeAllAnimations(); brand.layer.removeAllAnimations(); tagline.layer.removeAllAnimations(); thread.removeAllAnimations()
        let completion = onFinish; onFinish = nil; completion?()
    }
}
