import UIKit
import WebKit

enum AuthConsent {
    static var defaults: UserDefaults { ProcessInfo.processInfo.arguments.contains("--uitesting") ? UserDefaults(suiteName: "com.huankecontact.test.auth-tests")! : .standard }
    static var accepted: Bool { defaults.bool(forKey: "auth.privacy.v1") }
    static func accept() { defaults.set(true, forKey: "auth.privacy.v1") }
    static func reset() { defaults.removeObject(forKey: "auth.privacy.v1") }
}

final class AuthPrivacyController: UIViewController {
    var onAccept: (() -> Void)?
    var onDecline: (() -> Void)?
    init() { super.init(nibName: nil,bundle: nil); modalPresentationStyle = .overFullScreen; modalTransitionStyle = .crossDissolve }
    required init?(coder: NSCoder) { fatalError("init()") }
    override func viewDidLoad() {
        super.viewDidLoad(); view.backgroundColor = UIColor(red:24/255,green:37/255,blue:29/255,alpha:0.45)
        view.accessibilityViewIsModal = true
        let panel = UIView(); panel.backgroundColor = AuthStyle.cream; panel.layer.cornerRadius = 24
        panel.layer.maskedCorners = [.layerMinXMinYCorner,.layerMaxXMinYCorner]
        let scroll = UIScrollView(); let body = UIStackView(); body.axis = .vertical; body.spacing = 16
        for v in [panel,scroll,body] { v.translatesAutoresizingMaskIntoConstraints = false }
        view.addSubview(panel);panel.addSubview(scroll);scroll.addSubview(body)
        let preferred = panel.heightAnchor.constraint(equalToConstant: 572);preferred.priority = .defaultHigh
        NSLayoutConstraint.activate([panel.leadingAnchor.constraint(equalTo: view.leadingAnchor),panel.trailingAnchor.constraint(equalTo: view.trailingAnchor),panel.bottomAnchor.constraint(equalTo: view.bottomAnchor),panel.topAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor,constant: 16),preferred,scroll.topAnchor.constraint(equalTo:panel.topAnchor),scroll.leadingAnchor.constraint(equalTo:panel.leadingAnchor),scroll.trailingAnchor.constraint(equalTo:panel.trailingAnchor),scroll.bottomAnchor.constraint(equalTo:view.safeAreaLayoutGuide.bottomAnchor),body.topAnchor.constraint(equalTo:scroll.contentLayoutGuide.topAnchor,constant:24),body.leadingAnchor.constraint(equalTo:scroll.contentLayoutGuide.leadingAnchor,constant:24),body.trailingAnchor.constraint(equalTo:scroll.contentLayoutGuide.trailingAnchor,constant:-24),body.bottomAnchor.constraint(equalTo:scroll.contentLayoutGuide.bottomAnchor,constant:-24),body.widthAnchor.constraint(equalTo:scroll.frameLayoutGuide.widthAnchor,constant:-48)])
        let shield = AuthShieldView()
        shield.heightAnchor.constraint(equalToConstant:52).isActive = true
        body.addArrangedSubview(shield)
        body.addArrangedSubview(AuthStyle.label(AuthStyle.text("欢迎来到 Made Room","Welcome to Made Room"),size:22,bold:true,center:true))
        body.addArrangedSubview(AuthStyle.label(AuthStyle.text("开始使用前，请阅读《用户协议》和《隐私政策》，了解信息的使用方式与保护措施。","Before you begin, read the terms and privacy policy to learn how your information is used and protected.")))
        body.addArrangedSubview(AuthStyle.label(AuthStyle.text("相册、相机和通知权限，会在使用相关功能时另行询问。","Photos, camera and notification access will be requested when you use the relevant features.")))
        body.addArrangedSubview(AuthStyle.label(AuthStyle.text("你可以在设置中查看隐私相关选项。","You can review privacy options in Settings.")))
        let links=UIStackView();links.axis = .horizontal;links.distribution = .fillEqually
        for privacy in [false,true] { links.addArrangedSubview(AuthStyle.button(AuthStyle.text(privacy ? "隐私政策 ›":"用户协议 ›",privacy ? "Privacy policy ›":"Terms of use ›"),id:privacy ? "auth.consent.privacy":"auth.consent.terms",primary:false) { [weak self] in guard let self else { return }; LegalLinks.open(privacy: privacy, from: self) }) }
        body.addArrangedSubview(links)
        body.addArrangedSubview(AuthStyle.button(AuthStyle.text("同意并继续","Agree and continue"),id:"auth.privacy.accept") { [weak self] in AuthConsent.accept();self?.onAccept?() })
        let decline=AuthStyle.button(AuthStyle.text("暂不同意","Not now"),id:"auth.privacy.decline") { [weak self] in self?.onDecline?() }
        decline.backgroundColor = UIColor(red:233/255,green:236/255,blue:230/255,alpha:1);decline.setTitleColor(AuthStyle.ink,for:.normal);body.addArrangedSubview(decline)
    }
}

/// Shared destinations for consent, authentication and settings.
/// Legal documents are displayed in-app as explicitly requested.
enum LegalLinks {
    static let termsURL = URL(string: "https://docs.google.com/document/d/1mhk62gAOvWR7_8KEgJvazUwjDAJS-qjLJc9oFMUW_XM/edit?usp=sharing")!
    static let privacyURL = URL(string: "https://docs.google.com/document/d/1mhk62gAOvWR7_8KEgJvazUwjDAJS-qjLJc9oFMUW_XM/edit?usp=sharing")!

    static func open(privacy: Bool, from controller: UIViewController) {
        let legal = LegalWebViewController(privacy: privacy)
        let navigation = UINavigationController(rootViewController: legal)
        navigation.modalPresentationStyle = .fullScreen
        controller.present(navigation, animated: true)
    }
}

final class LegalWebViewController: AppWebViewController {
    init(privacy: Bool) {
        super.init(url: privacy ? LegalLinks.privacyURL : LegalLinks.termsURL,
                   title: AuthStyle.text(privacy ? "隐私政策" : "用户协议", privacy ? "Privacy policy" : "Terms of use"))
    }
    required init?(coder: NSCoder) { fatalError("init(privacy:)") }
}

/// Reusable container; privileged methods are opt-in for a future owned H5 page.
class AppWebViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    let documentURL: URL
    private(set) var webView: WKWebView!
    private let bridge: AppJavaScriptBridge
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let failure = UIStackView()
    private let failureLabel = UILabel()

    init(url: URL, title: String, bridge: AppJavaScriptBridge = AppJavaScriptBridge()) {
        documentURL = url
        self.bridge = bridge
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }
    required init?(coder: NSCoder) { fatalError("init(url:title:bridge:)") }
    deinit {
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: AppJavaScriptBridge.channel, contentWorld: .page)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AuthStyle.cream
        view.accessibilityIdentifier = "auth.legal.web"
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        if bridge.isEnabled {
            configuration.userContentController.addScriptMessageHandler(bridge, contentWorld: .page, name: AppJavaScriptBridge.channel)
        }
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.accessibilityIdentifier = "auth.legal.document"
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: AuthStyle.text("关闭", "Close"), style: .plain, target: self, action: #selector(close))
        navigationItem.leftBarButtonItem?.accessibilityIdentifier = "auth.legal.close"
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(retry))
        navigationItem.rightBarButtonItem?.accessibilityLabel = AuthStyle.text("重新加载", "Reload")
        navigationItem.rightBarButtonItem?.accessibilityIdentifier = "auth.legal.reload"
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(spinner)
        NSLayoutConstraint.activate([spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor), spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor)])
        failure.axis = .vertical; failure.spacing = 18; failure.alignment = .center
        failure.isHidden = true; failure.translatesAutoresizingMaskIntoConstraints = false
        failure.accessibilityIdentifier = "auth.legal.error"
        failureLabel.text = AuthStyle.text("页面暂时无法加载，请检查网络后重试。", "This page could not be loaded. Check your connection and try again.")
        failureLabel.numberOfLines = 0; failureLabel.textAlignment = .center
        failureLabel.font = AuthStyle.font(16); failureLabel.textColor = AuthStyle.ink
        failure.addArrangedSubview(failureLabel)
        failure.addArrangedSubview(AuthStyle.button(AuthStyle.text("重试", "Retry"), id: "auth.legal.retry") { [weak self] in self?.retry() })
        view.addSubview(failure)
        NSLayoutConstraint.activate([
            failure.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            failure.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            failure.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])
        retry()
    }
    @objc private func close() { webView.stopLoading(); dismiss(animated: true) }
    @objc private func retry() {
        failure.isHidden = true; webView.isHidden = false; spinner.startAnimating()
        webView.load(URLRequest(url: documentURL))
    }
    private func showFailure() {
        spinner.stopAnimating(); webView.isHidden = true; failure.isHidden = false
    }
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        failure.isHidden = true; webView.isHidden = false; spinner.startAnimating()
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { spinner.stopAnimating() }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code != NSURLErrorCancelled { showFailure() }
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code != NSURLErrorCancelled { showFailure() }
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { showFailure() }
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if navigationResponse.isForMainFrame, let response = navigationResponse.response as? HTTPURLResponse, response.statusCode >= 400 {
            showFailure(); decisionHandler(.cancel)
        } else { decisionHandler(.allow) }
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let scheme = navigationAction.request.url?.scheme?.lowercased(), ["https", "http", "about"].contains(scheme) else {
            decisionHandler(.cancel); return
        }
        decisionHandler(.allow)
    }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil,
           let scheme = navigationAction.request.url?.scheme?.lowercased(), ["https", "http"].contains(scheme) {
            webView.load(navigationAction.request)
        }
        return nil
    }
}


/// Origin equality includes HTTPS scheme, normalized host and effective port.
struct WebOrigin: Hashable {
    let host: String
    let port: Int
    init?(url: URL) {
        guard url.scheme?.lowercased() == "https", let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil else { return nil }
        self.host = host.lowercased(); self.port = url.port ?? 443
    }
    init?(securityOrigin: WKSecurityOrigin) {
        guard securityOrigin.protocol.lowercased() == "https", !securityOrigin.host.isEmpty else { return nil }
        host = securityOrigin.host.lowercased()
        port = securityOrigin.port == 0 ? 443 : securityOrigin.port
    }
}

/// No business actions or credentials are exposed by default.
final class AppJavaScriptBridge: NSObject, WKScriptMessageHandlerWithReply {
    typealias Method = ([String: Any]) throws -> [String: Any]
    static let channel = "madeRoom"
    private let origins: Set<WebOrigin>
    private let methods: [String: Method]
    var isEnabled: Bool { !origins.isEmpty && !methods.isEmpty }
    enum Failure: String, Error { case untrustedOrigin = "UNTRUSTED_ORIGIN", invalidMessage = "INVALID_MESSAGE", unsupportedMethod = "UNSUPPORTED_METHOD", invalidResult = "INVALID_RESULT" }

    init(origins: Set<WebOrigin> = [], methods: [String: Method] = [:]) {
        self.origins = origins; self.methods = methods
        super.init()
    }

    func response(to body: Any, origin: WebOrigin?, currentOrigin: WebOrigin?, mainFrame: Bool) throws -> [String: Any] {
        guard mainFrame, let origin, origin == currentOrigin, origins.contains(origin) else { throw Failure.untrustedOrigin }
        guard let message = body as? [String: Any], Set(message.keys) == ["version", "method", "params"],
              JSONSerialization.isValidJSONObject(message),
              let data = try? JSONSerialization.data(withJSONObject: message), data.count <= 65_536,
              let version = message["version"] as? NSNumber,
              CFGetTypeID(version) != CFBooleanGetTypeID(), version == 1,
              let name = message["method"] as? String, !name.isEmpty, name.utf8.count <= 64,
              let params = message["params"] as? [String: Any] else { throw Failure.invalidMessage }
        guard let method = methods[name] else { throw Failure.unsupportedMethod }
        let result = try method(params)
        guard JSONSerialization.isValidJSONObject(result),
              let data = try? JSONSerialization.data(withJSONObject: result), data.count <= 65_536 else { throw Failure.invalidResult }
        return result
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage, replyHandler: @escaping (Any?, String?) -> Void) {
        do {
            guard message.name == Self.channel else { throw Failure.invalidMessage }
            let result = try response(to: message.body,
                origin: WebOrigin(securityOrigin: message.frameInfo.securityOrigin),
                currentOrigin: message.webView?.url.flatMap { WebOrigin(url: $0) },
                mainFrame: message.frameInfo.isMainFrame)
            replyHandler(result, nil)
        } catch let failure as Failure {
            replyHandler(nil, failure.rawValue)
        } catch {
            replyHandler(nil, "NATIVE_ERROR")
        }
    }
}
