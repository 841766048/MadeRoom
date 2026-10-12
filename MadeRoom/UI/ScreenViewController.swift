import UIKit

/// Authored UIKit components with intrinsic sizing and Auto Layout; no screenshot renderer.
final class ScreenViewController: UIViewController {
    let screen: DesignScreen
    unowned let coordinator: AppCoordinator
    let scroll = UIScrollView()
    let body = RoomUI.stack(spacing:14)
    var fields: [String:UITextField] = [:]
    var editors: [String:UITextView] = [:]
    var creatorUID: String?
    var editorialPost: CommunityEditorialPost?
    var editorialTutorial = false
    var showsOwnPosts = false
    var segment = 0
    var requestID = UUID().uuidString
    var reportFingerprint = ""
    var commentReplyParentID: String?
    var commentReplyTo: String?
    var commentKnowledgeID = "woven-reading-corner"
    var commentKnowledgeTitle = "My woven reading corner"
    var commentsFeed = UIStackView()
    var commentCountLabel = UILabel()
    var commentStatusLabel = UILabel()
    var makingStep: Int?
    var profileSyncLabel = UILabel()
    var spaceSyncStatus: UILabel?
    var profileSyncRetry = UIButton()
    var profileFooter: UIView?
    private var actionBar: UIView?
    private var actionBarScrollConstraint: NSLayoutConstraint?
    private var retainedInput: [String:String] = [:]
    var input: [String:String] { fields.mapValues { $0.text ?? "" }.merging(editors.mapValues { $0.text ?? "" }) { _,b in b } }
    init(screen: DesignScreen, coordinator: AppCoordinator) { self.screen=screen;self.coordinator=coordinator;super.init(nibName:nil,bundle:nil);title=screen.name;hidesBottomBarWhenPushed = !ScreenRoutes.roots.contains(screen.id) }
    required init?(coder:NSCoder) { fatalError("Use semantic screen initializer") }
    override var preferredStatusBarStyle:UIStatusBarStyle { .darkContent }
    override func viewDidLoad() {
        super.viewDidLoad();view.backgroundColor = .roomCream;view.accessibilityIdentifier = "screen.\(screen.id)"
        scroll.translatesAutoresizingMaskIntoConstraints=false;body.translatesAutoresizingMaskIntoConstraints=false
        scroll.keyboardDismissMode = .interactive;view.addSubview(scroll);scroll.addSubview(body)
        let pageInset: CGFloat = screen.id == "P01" ? 0 : (["P02","P03","P04"].contains(screen.id) ? 18 * view.bounds.width / 333 : 20)
        NSLayoutConstraint.activate([scroll.topAnchor.constraint(equalTo:view.safeAreaLayoutGuide.topAnchor),scroll.leadingAnchor.constraint(equalTo:view.leadingAnchor),scroll.trailingAnchor.constraint(equalTo:view.trailingAnchor),body.topAnchor.constraint(equalTo:scroll.contentLayoutGuide.topAnchor,constant:8),body.bottomAnchor.constraint(equalTo:scroll.contentLayoutGuide.bottomAnchor,constant:-24),body.leadingAnchor.constraint(equalTo:scroll.contentLayoutGuide.leadingAnchor,constant:pageInset),body.trailingAnchor.constraint(equalTo:scroll.contentLayoutGuide.trailingAnchor,constant:-pageInset),body.widthAnchor.constraint(equalTo:scroll.frameLayoutGuide.widthAnchor,constant:-2*pageInset)])
        let bottom = scroll.bottomAnchor.constraint(equalTo:view.safeAreaLayoutGuide.bottomAnchor); bottom.priority = .defaultHigh; bottom.isActive = true
        #if DEBUG
        let inspect=UILongPressGestureRecognizer(target:self,action:#selector(inspectPages(_:)));inspect.minimumPressDuration=1.5;inspect.cancelsTouchesInView=false;view.addGestureRecognizer(inspect)
        #endif
    }
    override func viewWillAppear(_ animated:Bool) { super.viewWillAppear(animated);coordinator.tabs.updateBar();refresh()
        if screen.id == "C04" {
            coordinator.comments?.onChange = { [weak self] in self?.renderCommentFeed() }
            coordinator.comments?.listen(to: commentKnowledgeID)
        }
    }
    override func viewWillDisappear(_ animated: Bool) { super.viewWillDisappear(animated); retainedInput.merge(input) { _, new in new }
        if screen.id == "C04" { coordinator.comments?.onChange = nil; coordinator.comments?.unlisten() }
    }
    func refresh() {
        guard isViewLoaded else{return}
        retainedInput.merge(input) { _, new in new }
        coordinator.updateLanguageContent()
        actionBarScrollConstraint?.isActive = false; actionBarScrollConstraint = nil
        actionBar?.removeFromSuperview(); actionBar = nil
        profileFooter?.removeFromSuperview();profileFooter=nil;scroll.contentInset.bottom=0;scroll.verticalScrollIndicatorInsets.bottom=0
        body.arrangedSubviews.forEach{$0.removeFromSuperview()};fields.removeAll();editors.removeAll()
        switch screen.id.prefix(1) {
        case "D": buildDiscover()
        case "M": buildMaking()
        case "S": buildSpaces()
        case "C": buildCommunity()
        case "P": buildProfile()
        default: buildStates()
        }
        if ["P01","P02","P05","P07","P09","M01","M03","M05"].contains(screen.id), let sync=coordinator.librarySync {
            let status=RoomUI.label(sync.status,size:12,color:.secondaryLabel);status.accessibilityIdentifier="account.sync.status";add(status)
            if sync.status != "Account synced" { add(action("Retry sync","@syncRetry")) }
        }
        installFixedActions()
        for (key,value) in retainedInput { fields[key]?.text=value; editors[key]?.text=value }
        if screen.id == "D02" { showSearchResults() }
        if screen.id == "P04" { fields["username"]?.sendActions(for:.editingChanged) }
    }
    @objc private func inspectPages(_ g:UILongPressGestureRecognizer) { if g.state == .began { coordinator.showCatalog() } }
    func add(_ v:UIView) { body.addArrangedSubview(v) }
    func heading(_ title:String, subtitle:String?=nil) { add(RoomUI.label(title,size:30,weight:.bold));if let subtitle {add(RoomUI.label(subtitle,size:15,color:.secondaryLabel))} }
    func toolbar(_ title:String, back:Bool=true, trailing:String?=nil, action:String?=nil) {
        if navigationController?.viewControllers.first !== self {
            navigationItem.title = AppLanguage.text(title)
            let previous = UIBarButtonItem(image: UIImage(systemName:"chevron.left"), style:.plain, target:self, action:#selector(goBack))
            previous.accessibilityIdentifier = "navigation.back"; previous.accessibilityLabel = AppLanguage.text("Back")
            if ["P01","P02","P03","P04","M02","M03","M04","M05","M06","M07","C04","C05","C06"].contains(screen.id) {
                previous.tintColor = .label
                if #available(iOS 26.0, *) { previous.hidesSharedBackground = true }
            }
            navigationItem.leftBarButtonItem = previous
            if let trailing {
                let item = UIBarButtonItem(image:UIImage(systemName:trailing),primaryAction:UIAction { [weak self] _ in if let action { self?.act(action) } })
                item.accessibilityIdentifier = action.map { "action.\(screen.id).\($0)" }
                item.accessibilityLabel = action == "P05" ? "Settings" : "More"
                if ["P01","P02","P03","P04","M02","M03","M04","M05","M06","M07","C04","C05","C06"].contains(screen.id) {
                    item.tintColor = .label
                    if #available(iOS 26.0, *) { item.hidesSharedBackground = true }
                }
                navigationItem.rightBarButtonItem = item
            }
            return
        }
        let row=RoomUI.stack(axis:.horizontal,spacing:8);row.alignment = .center
        if back {let b=RoomUI.button("",icon:"chevron.left"){[weak self] in self?.coordinator.back()};b.accessibilityLabel=AppLanguage.text("Back");b.accessibilityIdentifier="navigation.back";row.addArrangedSubview(b)}
        let titleLabel=RoomUI.label(title,size:20,weight:.bold);titleLabel.setContentHuggingPriority(.defaultLow,for:.horizontal);row.addArrangedSubview(titleLabel)
        if let trailing {let b=RoomUI.button("",icon:trailing){[weak self] in if let action {self?.act(action)}};b.accessibilityLabel=action == "P05" ? "Settings" : "More";if let action {b.accessibilityIdentifier="action.\(screen.id).\(action)"};row.addArrangedSubview(b)}
        add(row)
    }
    @objc private func goBack() { coordinator.back() }
    func action(_ title:String,_ code:String,primary:Bool=false,icon:String?=nil)->UIButton {
        let b=RoomUI.button(title,icon:icon,primary:primary){[weak self] in self?.act(code,label:title)};b.accessibilityIdentifier="action.\(screen.id).\(code)";return b
    }
    func act(_ code:String,label:String="") { if !handleEditorialAction(code) { coordinator.handle(code,from:self,label:label) } }
    func field(_ name:String,key:String,value:String="",placeholder:String="") {
        let f=UITextField();f.text=value;f.placeholder=AppLanguage.text(placeholder);f.font = .preferredFont(forTextStyle:.body);f.adjustsFontForContentSizeCategory=true;f.clearButtonMode = .whileEditing;f.returnKeyType = .done;f.accessibilityLabel=AppLanguage.text(name);f.accessibilityIdentifier="input.\(key)";f.heightAnchor.constraint(greaterThanOrEqualToConstant:48).isActive=true
        f.addAction(UIAction{[weak f]_ in f?.resignFirstResponder()},for:.editingDidEndOnExit)
        fields[key]=f;add(RoomUI.stack([RoomUI.label(name,size:13,weight:.medium,color:.secondaryLabel),RoomUI.card(f,inset:10)],spacing:6))
    }
    func editor(_ name:String,key:String,value:String="") {
        let v=UITextView();v.text=value;v.font = .preferredFont(forTextStyle:.body);v.adjustsFontForContentSizeCategory=true;v.isScrollEnabled=false;v.backgroundColor = .white;v.layer.cornerRadius=12;v.textContainerInset=UIEdgeInsets(top:14,left:12,bottom:14,right:12);v.heightAnchor.constraint(greaterThanOrEqualToConstant:112).isActive=true;v.accessibilityLabel=AppLanguage.text(name);v.accessibilityIdentifier="input.\(key)";editors[key]=v
        let done=UIToolbar();done.sizeToFit();done.items=[UIBarButtonItem(systemItem:.flexibleSpace),UIBarButtonItem(title:AppLanguage.text("Done"),primaryAction:UIAction{[weak v]_ in v?.resignFirstResponder()})];v.inputAccessoryView=done
        add(RoomUI.stack([RoomUI.label(name,size:13,weight:.medium,color:.secondaryLabel),v],spacing:6))
    }
    func row(_ title:String,subtitle:String?=nil,icon:String?=nil,code:String)->UIView {
        let b=action(title,code,icon:icon);b.contentHorizontalAlignment = .leading
        if let subtitle {return RoomUI.card(RoomUI.stack([b,RoomUI.label(subtitle,size:13,color:.secondaryLabel)],spacing:2))};return RoomUI.card(b,inset:4)
    }
    func segments(_ titles:[String],selected:Int=0,onChange:((Int)->Void)?=nil) {
        let v=UISegmentedControl(items:titles.map(AppLanguage.text));v.selectedSegmentIndex=selected;v.selectedSegmentTintColor = .white;v.addAction(UIAction{[weak self,weak v]_ in guard let v else{return};self?.segment=v.selectedSegmentIndex;onChange?(v.selectedSegmentIndex)},for:.valueChanged);add(v)
    }
    func toggle(_ title:String,key:String,defaultValue:Bool=false) {
        let label=RoomUI.label(title,size:16);let v=UISwitch();v.onTintColor = .roomGreen;v.isOn=(key.hasPrefix("plan.") ? coordinator.store.state.spaceDetails?[coordinator.selectedSpace]?.plan?[key] : coordinator.store.state.preferences[key]) ?? defaultValue;v.accessibilityLabel=AppLanguage.text(title)
        v.addAction(UIAction{[weak self,weak v]_ in guard let self,let v else{return};self.coordinator.perform{if key.hasPrefix("plan.") { try self.coordinator.store.setSpacePlan(self.coordinator.selectedSpace,key:key,value:v.isOn) } else { try self.coordinator.store.setPreference(key,value:v.isOn) }}},for:.valueChanged)
        let row=RoomUI.stack([label,v],axis:.horizontal);row.alignment = .center;add(RoomUI.card(row))
    }
    func photo(_ asset:String,ratio:CGFloat=0.7)->UIImageView { let v=RoomUI.image(asset,ratio:ratio);add(v);return v }
    func profilePhoto() -> UIImage? {
        if let data = coordinator.store.state.profileAvatarData { return UIImage(data: data) }
        return localPhoto(coordinator.store.state.profilePhoto)
    }
    func localPhoto(_ name:String?) -> UIImage? { guard let name else{return nil};return UIImage(contentsOfFile:FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent(name).path) }
    func artworkCard(_ asset:String,title:String,subtitle:String,code:String)->UIView {
        let photo=RoomUI.image(asset,ratio:0.63,radius:14)
        let button=action(title,code);button.contentHorizontalAlignment = .leading
        let v=RoomUI.card(RoomUI.stack([photo,button,RoomUI.label(subtitle,size:13,color:.secondaryLabel)],spacing:6),inset:10);return v
    }
}


extension ScreenViewController {
    /// Only primary page actions leave the document flow; inline controls remain scrollable.
    private func installFixedActions() {
        let routes: [String: [String]] = [
            "D03": ["@save"], "D04": ["@save", "M02"],
            "M02": ["@createProject"], "M03": ["M04", "M05"],
            "M04": ["@previousStep", "@advance"], "M05": ["@place", "C02"],
            "M06": ["@saveNote"], "M07": ["@editProject"],
            "S02": ["C02"], "S03": ["@saveSpace"], "S04": ["@savePlan"],
            "C02": ["@draft", "@publish"], "C13": ["@draft", "@publish"],
            "C03": ["D04", "C10"],
            "C09": ["@joinChallenge", "C11"], "C10": ["@createProject"], "C11": ["@submitChallenge"]
        ]
        guard let codes = routes[screen.id] else { return }
        func find(_ container: UIView, identifier: String) -> UIButton? {
            if let button = container as? UIButton, button.accessibilityIdentifier == identifier { return button }
            for child in container.subviews.reversed() { if let button = find(child, identifier: identifier) { return button } }
            return nil
        }
        let buttons = codes.compactMap { find(body, identifier: "action.\(screen.id).\($0)") }
        guard !buttons.isEmpty else { return }
        for button in buttons {
            let parent = button.superview as? UIStackView
            parent?.removeArrangedSubview(button); button.removeFromSuperview()
            if let parent, parent !== body, parent.arrangedSubviews.isEmpty { parent.removeFromSuperview() }
        }
        let bar = UIView(); bar.backgroundColor = .roomCream; bar.translatesAutoresizingMaskIntoConstraints = false
        bar.accessibilityIdentifier = "screen.actions"
        let row = RoomUI.stack(buttons, axis: .horizontal, spacing: 12); row.distribution = .fillEqually
        if screen.id == "M05" || traitCollection.preferredContentSizeCategory.isAccessibilityCategory { row.axis = .vertical }
        row.translatesAutoresizingMaskIntoConstraints = false; bar.addSubview(row); view.addSubview(bar)
        let bottom = bar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor); bottom.priority = .defaultHigh
        let scrollBottom = scroll.bottomAnchor.constraint(equalTo: bar.topAnchor)
        NSLayoutConstraint.activate([
            bar.leadingAnchor.constraint(equalTo: view.leadingAnchor), bar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bar.bottomAnchor.constraint(lessThanOrEqualTo: view.keyboardLayoutGuide.topAnchor), bottom,
            row.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 20), row.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -20),
            row.topAnchor.constraint(equalTo: bar.topAnchor, constant: 10), row.bottomAnchor.constraint(equalTo: bar.bottomAnchor, constant: -10), scrollBottom
        ])
        actionBar = bar; actionBarScrollConstraint = scrollBottom
    }
}
