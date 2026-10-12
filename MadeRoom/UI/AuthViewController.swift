import UIKit
import FirebaseAuth
import CoreText

/// UIKit implementation of the approved Pixso account flow. No screen-image playback.
final class AuthViewController: UIViewController, UITextFieldDelegate {
    enum Page { case login, register, reset }
    let page: Page
    private let showConsent: Bool
    private let stack = UIStackView()
    private let scroll = UIScrollView()
    private var email = UITextField()
    private var password = UITextField()
    private var confirmation = UITextField()
    private var submit = UIButton()
    private var isSubmitting = false
    private var loadingTicket: NetworkLoadingTicket?
    private var agreement = false
    private var didPresentConsent = false
    private var rememberedEmail = ""
    init(page: Page = .login, showConsent: Bool = false) {
        self.page = page; self.showConsent = showConsent
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }
    required init?(coder: NSCoder) { fatalError("Use init(page:)") }
    override var preferredStatusBarStyle: UIStatusBarStyle { .darkContent }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AuthStyle.cream
        view.accessibilityIdentifier = "auth.\(page)"
        scroll.keyboardDismissMode = .interactive
        scroll.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical; stack.spacing = 0
        view.addSubview(scroll); scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -12),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor)
        ])
        switch page { case .login: buildLogin(); case .register: buildRegister(); case .reset: buildReset() }
        email.text = rememberedEmail
        updateValidation()
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated); navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if showConsent && !didPresentConsent {
            didPresentConsent = true
            let consent = AuthPrivacyController()
            consent.onAccept = { [weak self] in self?.dismiss(animated: true) }
            consent.onDecline = { [weak self] in
                self?.dismiss(animated: true)
            }
            present(consent, animated: false)
        }
    }
    private func add(_ child: UIView, gap: CGFloat = 0, inset: CGFloat = 24) {
        let wrapper = UIView(); wrapper.addSubview(child); child.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([child.topAnchor.constraint(equalTo: wrapper.topAnchor), child.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor), child.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: inset), child.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -inset)])
        stack.addArrangedSubview(wrapper); stack.setCustomSpacing(gap, after: wrapper)
    }
    private func label(_ zh: String, _ en: String, size: CGFloat = 16, bold: Bool = false, center: Bool = false) -> UILabel {
        AuthStyle.label(AuthStyle.text(zh, en), size: size, bold: bold, center: center)
    }
    private func title(_ zh: String, _ en: String, center: Bool = false) {
        add(label(zh, en, size: 26, bold: true, center: center), gap: 6)
    }
    private func link(_ zh: String, _ en: String, id: String, action: @escaping () -> Void) -> UIButton {
        AuthStyle.button(AuthStyle.text(zh, en), id: id, primary: false, action: action)
    }
    private func buildLogin() {
        let hero = AuthHeroView()
        hero.heightAnchor.constraint(equalToConstant: 318).isActive = true
        add(hero, gap: 5, inset: 0)
        title("欢迎回来", "Welcome back", center: true)
        add(label("继续你的手作与空间生活", "Continue your creative home life", center: true), gap: 21)
        add(field("邮箱", "Email", key: "email"), gap: 10)
        add(field("密码", "Password", key: "password"))
        let forgot = link("忘记密码？", "Forgot password?", id: "auth.forgot") { [weak self] in self?.open(.reset) }
        forgot.contentHorizontalAlignment = .right
        add(forgot)
        submit = AuthStyle.button(AuthStyle.text("登录", "Sign in"), id: "auth.submit") { [weak self] in self?.send() }
        add(submit)
        add(link("还没有账号？ 注册", "New here? Create an account", id: "auth.register") { [weak self] in self?.open(.register) })
        add(legalLinks())
    }
    private func back() {
        view.endEditing(true)
        if (navigationController?.viewControllers.count ?? 0) > 1 { navigationController?.popViewController(animated: true) }

    }
    private func backLink() -> UIButton {
        let b = link("‹  返回", "‹  Back", id: "auth.back") { [weak self] in self?.back() }
        b.contentHorizontalAlignment = .left; return b
    }
    private func buildRegister() {
        add(backLink(), gap: 32)
        let header = UIView()
        let heading = label("创建账号", "Create account", size: 26, bold: true)
        let sub = label("从一个小小的创作开始", "Start with a little creativity")
        let art = AuthStyle.art("auth-mug")
        for v in [heading,sub,art] { header.addSubview(v); v.translatesAutoresizingMaskIntoConstraints = false }
        NSLayoutConstraint.activate([
            header.heightAnchor.constraint(greaterThanOrEqualToConstant: 121),
            heading.leadingAnchor.constraint(equalTo: header.leadingAnchor), heading.topAnchor.constraint(equalTo: header.topAnchor),
            heading.trailingAnchor.constraint(lessThanOrEqualTo: art.leadingAnchor, constant: -8),
            sub.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: 6), sub.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            sub.trailingAnchor.constraint(lessThanOrEqualTo: art.leadingAnchor, constant: -8), sub.bottomAnchor.constraint(lessThanOrEqualTo: header.bottomAnchor),
            art.trailingAnchor.constraint(equalTo: header.trailingAnchor), art.topAnchor.constraint(equalTo: header.topAnchor, constant: -28),
            art.widthAnchor.constraint(equalToConstant: 99), art.heightAnchor.constraint(equalToConstant: 110)
        ])
        add(header)
        add(field("邮箱", "Email", key: "email"), gap: 18)
        add(field("设置密码", "Password", key: "password"), gap: 6)
        add(label("至少 8 位，包含字母和数字", "At least 8 characters, with letters and numbers", size: 14), gap: 19)
        add(field("确认密码", "Confirm password", key: "confirm"), gap: 18)
        let check = AuthAgreementButton { [weak self] in
            guard let self else { return }; self.agreement.toggle(); self.updateValidation()
        }
        add(check); add(legalLinks(), gap: 20)
        submit = AuthStyle.button(AuthStyle.text("创建账号", "Create account"), id: "auth.submit") { [weak self] in self?.send() }
        add(submit, gap: 8)
        add(link("已有账号？ 登录", "Already a member? Sign in", id: "auth.login") { [weak self] in self?.back() })
    }
    private func buildReset() {
        add(backLink(), gap: 30)
        let art = AuthStyle.art("auth-envelope"); art.heightAnchor.constraint(equalToConstant: 99).isActive = true
        add(art, gap: 30, inset: 134)
        title("忘记密码了？", "Forgot your password?", center: true)
        add(label("输入注册邮箱，我们会发送\n重置密码邮件。", "Enter your email to request\na password reset link.", center: true), gap: 43)
        add(field("邮箱", "Email", key: "email"), gap: 26)
        submit = AuthStyle.button(AuthStyle.text("发送重置邮件", "Send reset email"), id: "auth.submit") { [weak self] in self?.send() }
        add(submit, gap: 7)
        add(link("返回登录", "Back to sign in", id: "auth.login") { [weak self] in self?.back() }, gap: 58)
        let plant = AuthStyle.art("auth-plant"), holder = UIView()
        holder.addSubview(plant);plant.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([holder.heightAnchor.constraint(equalToConstant:116),plant.trailingAnchor.constraint(equalTo:holder.trailingAnchor),plant.topAnchor.constraint(equalTo:holder.topAnchor),plant.widthAnchor.constraint(equalToConstant:116),plant.heightAnchor.constraint(equalToConstant:116)])
        add(holder)
    }
    private func field(_ zh: String, _ en: String, key: String) -> UIView {
        let column = UIStackView(); column.axis = .vertical; column.spacing = 5
        let caption = label(zh, en, size: 15)
        caption.textColor = AuthStyle.ink
        column.addArrangedSubview(caption)
        let input = UITextField(); input.font = AuthStyle.font(17); input.textColor = AuthStyle.ink
        input.backgroundColor = .white; input.layer.cornerRadius = 12; input.layer.borderWidth = 1
        input.layer.borderColor = UIColor(red: 218/255, green: 225/255, blue: 218/255, alpha: 1).cgColor
        input.heightAnchor.constraint(equalToConstant: 52).isActive = true
        input.leftView = UIView(frame: CGRect(x: 0,y: 0,width: 16,height: 20)); input.leftViewMode = .always
        input.autocorrectionType = .no; input.autocapitalizationType = .none; input.spellCheckingType = .no
        input.accessibilityIdentifier = "auth.\(key)"; input.accessibilityLabel = AuthStyle.text(zh, en)
        input.returnKeyType = .next; input.delegate = self
        input.addTarget(self, action: #selector(updateValidation), for: .editingChanged)
        if key == "email" {
            email = input; input.keyboardType = .emailAddress; input.textContentType = .username; input.placeholder = "you@example.com"
        } else {
            input.keyboardType = .asciiCapable
            input.isSecureTextEntry = true
            input.textContentType = page == .register ? .newPassword : .password
            if page == .register { input.passwordRules = UITextInputPasswordRules(descriptor: "required: lower; required: digit; minlength: 8;") }
            input.placeholder = AuthStyle.text("请输入密码", "Enter password")
            if key == "password" { password = input } else { confirmation = input; input.returnKeyType = .done }
            let eye = UIButton(type: .system); eye.frame = CGRect(x: 0,y: 0,width: 44,height: 44)
            eye.setImage(UIImage(systemName: "eye"), for: .normal); eye.tintColor = AuthStyle.muted
            eye.accessibilityIdentifier = "auth.reveal.\(key)"; eye.accessibilityLabel = AuthStyle.text("显示密码", "Show password")
            eye.addAction(UIAction { [weak input, weak eye] _ in
                guard let input else { return }; input.isSecureTextEntry.toggle()
                eye?.setImage(UIImage(systemName: input.isSecureTextEntry ? "eye" : "eye.slash"), for: .normal)
                eye?.accessibilityLabel = input.isSecureTextEntry ? AuthStyle.text("显示密码", "Show password") : AuthStyle.text("隐藏密码", "Hide password")
            }, for: .touchUpInside)
            input.rightView = eye; input.rightViewMode = .always
        }
        if let placeholder = input.placeholder { input.attributedPlaceholder = NSAttributedString(string: placeholder, attributes: [.foregroundColor: AuthStyle.muted]) }
        let toolbar = UIToolbar(); toolbar.sizeToFit()
        let done = UIBarButtonItem(title: AuthStyle.text("完成", "Done"), style: .done, target: self, action: #selector(endInput))
        done.accessibilityIdentifier = "auth.keyboardDone"
        toolbar.items = [UIBarButtonItem(systemItem: .flexibleSpace),done]; input.inputAccessoryView = toolbar
        column.addArrangedSubview(input); return column
    }
    func textFieldDidBeginEditing(_ textField: UITextField) {
        DispatchQueue.main.asyncAfter(deadline: .now()+0.3) { [weak self, weak textField] in
            guard let self, let textField else { return }
            self.scroll.scrollRectToVisible(textField.convert(textField.bounds.insetBy(dx: 0, dy: -30), to: self.scroll), animated: true)
        }
    }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === email && page != .reset { password.becomeFirstResponder() }
        else if textField === password && page == .register { confirmation.becomeFirstResponder() }
        else { view.endEditing(true) }; return true
    }
    @objc private func endInput() { view.endEditing(true) }
    @objc private func updateValidation() {
        if page == .register {
            submit.isEnabled = !isSubmitting && AuthValidation.canRegister(email: email.text ?? "", password: password.text ?? "", confirmation: confirmation.text ?? "", agreed: agreement)
            submit.backgroundColor = submit.isEnabled ? AuthStyle.green : AuthStyle.disabled
            if let check = view.findAuthButton("auth.agreement") { check.isSelected = agreement }
        }
    }
    private func open(_ next: Page) {
        view.endEditing(true)
        let vc = AuthViewController(page: next); vc.rememberedEmail = email.text ?? ""
        navigationController?.pushViewController(vc, animated: true)
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        loadingTicket?.finish()
    }
    private func send() {
        view.endEditing(true)
        guard AuthValidation.validEmail(email.text ?? "") else { alert("请检查邮箱", "Check your email", "请输入有效的邮箱地址。", "Enter a valid email address."); return }
        if page == .login && (password.text ?? "").isEmpty { alert("请输入密码", "Password required", "填写密码后再继续。", "Enter your password to continue."); return }
        if page == .register && !AuthValidation.canRegister(email: email.text ?? "", password: password.text ?? "", confirmation: confirmation.text ?? "", agreed: agreement) { return }
        guard !isSubmitting else { return }
        if page == .register { AuthConsent.accept() }
        isSubmitting = true; submit.isEnabled = false
        let ticket = NetworkLoading.shared.begin()
        loadingTicket = ticket
        let address = (email.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let secret = password.text ?? ""
        Task { [weak self] in
            defer { ticket.finish() }
            guard let self else { return }
            defer { self.isSubmitting = false; self.submit.isEnabled = true; self.updateValidation() }
            do {
                switch self.page {
                case .login: _ = try await AccountService.auth.signIn(withEmail: address, password: secret)
                case .register: _ = try await AccountService.auth.createUser(withEmail: address, password: secret)
                case .reset:
                    try await AccountService.auth.sendPasswordReset(withEmail: address)
                    self.alert("请检查邮箱", "Check your inbox", "如果此邮箱可以重置密码，你将收到后续邮件。", "If this email is eligible for a password reset, you will receive further instructions.")
                }
            } catch {
                let code = (error as NSError).code
                if self.page == .reset && code == AuthErrorCode.userNotFound.rawValue {
                    self.alert("请检查邮箱", "Check your inbox", "如果此邮箱可以重置密码，你将收到后续邮件。", "If this email is eligible for a password reset, you will receive further instructions.")
                    self.isSubmitting = false; self.submit.isEnabled = true
                    return
                }
                let message: String
                switch code {
                case AuthErrorCode.networkError.rawValue: message = "Check your connection and try again."
                case AuthErrorCode.tooManyRequests.rawValue: message = "Too many attempts. Please try again later."
                case AuthErrorCode.weakPassword.rawValue: message = "Choose a stronger password and try again."
                default: message = "We could not complete this request. Check your details or try resetting your password."
                }
                self.alert("无法完成请求", "Unable to continue", message, message)
            }
            self.isSubmitting = false
            self.submit.isEnabled = true
            self.updateValidation()
        }
    }
    private func alert(_ zh: String, _ en: String, _ bodyZH: String, _ bodyEN: String) {
        loadingTicket?.finish()
        let a = UIAlertController(title: AuthStyle.text(zh,en), message: AuthStyle.text(bodyZH,bodyEN), preferredStyle: .alert)
        a.addAction(UIAlertAction(title: AuthStyle.text("好","OK"), style: .default)); present(a, animated: true)
    }
    private func legalLinks() -> UIView {
        let row = UIStackView(); row.axis = .horizontal; row.distribution = .fillEqually
        for privacy in [false,true] {
            row.addArrangedSubview(link(privacy ? "隐私政策" : "用户协议", privacy ? "Privacy policy" : "Terms of use", id: privacy ? "auth.privacy" : "auth.terms") { [weak self] in guard let self else { return }; LegalLinks.open(privacy: privacy, from: self) })
        }; return row
    }
}

enum AuthValidation {
    static func validEmail(_ value: String) -> Bool {
        let email = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return email.range(of: #"^[A-Z0-9a-z.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)+$"#, options: .regularExpression) != nil
    }
    static func canRegister(email: String, password: String, confirmation: String, agreed: Bool) -> Bool {
        agreed && validEmail(email) && password.count >= 8 && password.rangeOfCharacter(from: .letters) != nil && password.rangeOfCharacter(from: .decimalDigits) != nil && password == confirmation
    }
}

private extension UIView {
    func findAuthButton(_ id: String) -> UIButton? {
        if let b = self as? UIButton, b.accessibilityIdentifier == id { return b }
        return subviews.lazy.compactMap { $0.findAuthButton(id) }.first
    }
}
