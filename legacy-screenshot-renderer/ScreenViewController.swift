import UIKit

final class ScreenViewController: UIViewController {
    let screen: DesignScreen
    unowned let coordinator: AppCoordinator
    private let scroll = UIScrollView()
    let content = UIView()
    var labels: [(DesignText, UILabel)] = []
    private var textFields: [String: UITextField] = [:]
    var projectCards: [UIView] = []
    var liveDataViews: [UIView] = []
    var minimumContentHeight: CGFloat = 0
    private var keyboardObserver: NSObjectProtocol?
    var input: [String: String] { textFields.mapValues { $0.text ?? "" } }

    init(screen: DesignScreen, coordinator: AppCoordinator) {
        self.screen = screen; self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
        title = screen.name
        hidesBottomBarWhenPushed = !ScreenRoutes.roots.contains(screen.id)
    }
    required init?(coder: NSCoder) { fatalError("Use init(screen:coordinator:)") }
    override var preferredStatusBarStyle: UIStatusBarStyle { .darkContent }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(rgb: screen.background)
        view.accessibilityIdentifier = "screen.\(screen.id)"
        scroll.backgroundColor = view.backgroundColor
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.keyboardDismissMode = .interactive
        view.addSubview(scroll); scroll.addSubview(content)
        let surface = SurfaceView(screen: screen)
        surface.frame = CGRect(x: 0, y: 0, width: screen.width, height: screen.height)
        content.addSubview(surface)
        for item in screen.images {
            let image = UIImageView(image: DesignCatalog.image(item.name))
            image.frame = CGRect(box: item.box); image.contentMode = .scaleToFill
            image.isAccessibilityElement = false
            content.addSubview(image)
        }
        for item in screen.texts {
            if shouldExclude(item) { continue }
            let label = UILabel(frame: CGRect(box: item.box))
            label.text = item.text
            label.font = UIFont(name: item.bold ? "Arial-BoldMT" : "ArialMT", size: item.fontSize) ?? .systemFont(ofSize: item.fontSize, weight: item.bold ? .bold : .regular)
            label.textColor = UIColor(rgb: item.color)
            label.numberOfLines = 1
            label.adjustsFontSizeToFitWidth = true; label.minimumScaleFactor = 0.78
            label.accessibilityIdentifier = "text.\(screen.id).\(item.text)"
            content.addSubview(label); labels.append((item, label))
            if let action = ScreenRoutes.action(for: item.text, on: screen.id) {
                let frame = label.frame.insetBy(dx: -5, dy: -7)
                addAction(frame, name: item.text, action: action)
                label.isAccessibilityElement = false
            }
        }
        installImageActions()
        installFields()
        installSettingsSwitches()
        installUtilityControls()
        keyboardObserver = NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillChangeFrameNotification, object: nil, queue: .main) { [weak self] note in
            guard let self, let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            let keyboard = self.view.convert(frame, from: nil)
            self.scroll.contentInset.bottom = max(0, self.view.bounds.maxY - keyboard.minY - self.view.safeAreaInsets.bottom)
            self.scroll.verticalScrollIndicatorInsets.bottom = self.scroll.contentInset.bottom
        }
    }
    deinit { if let keyboardObserver { NotificationCenter.default.removeObserver(keyboardObserver) } }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
        refreshState()
        coordinator.tabs.updateBar()
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let safe = view.safeAreaInsets
        scroll.frame = CGRect(x: 0, y: safe.top, width: view.bounds.width, height: view.bounds.height-safe.top-safe.bottom)
        let scale = view.bounds.width / screen.width
        content.transform = .identity
        content.frame = CGRect(x: 0, y: -screen.top*scale, width: screen.width, height: screen.height)
        content.layer.anchorPoint = .zero; content.layer.position = CGPoint(x: 0, y: -screen.top*scale)
        content.transform = CGAffineTransform(scaleX: scale, y: scale)
        scroll.contentSize = CGSize(width: view.bounds.width, height: max(screen.bottom-screen.top, minimumContentHeight-screen.top)*scale + 12)
    }
    private func shouldExclude(_ text: DesignText) -> Bool {
        // The validation board includes a drawn keyboard. Real UIKit fields use the system keyboard.
        if screen.id == "X06", text.box[1] > screen.height*0.68 { return true }
        if ["Discover", "Make", "Spaces", "Community", "Profile"].contains(text.text), text.box[1] > screen.height*0.82 { return true }
        return false
    }
    private func addAction(_ frame: CGRect, name: String, action: String) {
        let button = UIButton(type: .custom)
        button.frame = frame
        button.accessibilityLabel = name
        button.accessibilityIdentifier = "action.\(screen.id).\(action)"
        button.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            UISelectionFeedbackGenerator().selectionChanged()
            self.coordinator.handle(action, from: self, label: name)
        }, for: .touchUpInside)
        content.addSubview(button)
    }
    private func installImageActions() {
        let large = screen.images.filter { $0.box[2] > 65 && $0.box[3] > 65 && $0.name.contains("media") }
        let destinations: [String: String] = ["D01":"D03", "D02":"D04", "D03":"D04", "M01":"M03", "S01":"S02", "S02":"S04", "C01":"C03", "C05":"C03", "C07":"C08", "C08":"C09", "P01":"M03", "P02":"P09", "P09":"D04", "S05":"@select"]
        if let target = destinations[screen.id] {
            for item in large { addAction(CGRect(box: item.box), name: "Open \(screen.name) item", action: target) }
        }
    }
    private func installFields() {
        let fieldMap: [String: [(String, String)]] = [
            "D02":[("woven","query")], "X12":[("glassblowing","query")],
            "M02":[("Woven wall hanging","name")], "C10":[("My woven wall hanging","name")],
            "M07":[("Woven wall hanging","name")], "S03":[("Reading corner","space"), ("A cozy spot for slow mornings and", "spaceNotes")],
            "C02":[("My woven reading corner","title"), ("A cozy corner for slower days. Handwoven","body")],
            "C13":[("My Woven Reading Corner","title"), ("A cozy little corner with a handmade","body")],
            "P04":[("Maya Chen","name"), ("Making a home, one piece at a time.","bio")],
            "P10":[("Weekend makes","collection")], "M06":[("Trying a softer fringe","note")],
            "A02":[("you@example.com","email")], "X06":[("e.g. Cozy Reading Pillow","name")]
        ]
        for (source, key) in fieldMap[screen.id] ?? [] {
            let match = screen.id == "P10" ? labels.last(where: { $0.0.text == source }) : labels.first(where: { $0.0.text == source })
            guard let (item,label) = match else { continue }
            label.isHidden = true
            let field = UITextField(frame: CGRect(box: item.box).insetBy(dx: -2, dy: -6))
            field.backgroundColor = UIColor(rgb: screen.background)
            field.textColor = .label; field.tintColor = .roomGreen
            field.font = .systemFont(ofSize: max(13, item.fontSize))
            field.text = source; field.clearButtonMode = .whileEditing
            field.accessibilityLabel = key.capitalized; field.accessibilityIdentifier = "input.\(key)"
            field.autocorrectionType = key == "email" ? .no : .default
            if key == "email" { field.keyboardType = .emailAddress; field.autocapitalizationType = .none }
            if key == "query" {
                field.returnKeyType = .search
                field.addAction(UIAction { [weak self, weak field] _ in
                    guard let self else { return }
                    field?.resignFirstResponder()
                    self.coordinator.search(field?.text ?? "", from: self)
                }, for: .editingDidEndOnExit)
            } else { field.returnKeyType = .done; field.addAction(UIAction { [weak field] _ in field?.resignFirstResponder() }, for: .editingDidEndOnExit) }
            content.addSubview(field); textFields[key] = field
        }
    }
    private func installSettingsSwitches() {
        guard screen.id == "P07" else { return }
        for (item, _) in labels where ["Replies to your posts", "New followers", "Challenge updates"].contains(item.text) {
            let toggle = UISwitch(frame: CGRect(x: screen.width-70, y: item.box[1], width: 51, height: 31))
            toggle.onTintColor = .roomGreen
            toggle.isOn = coordinator.store.state.preferences[item.text] ?? true
            toggle.accessibilityLabel = item.text
            toggle.addAction(UIAction { [weak self, weak toggle] _ in
                guard let self, let toggle else { return }
                self.coordinator.perform { try self.coordinator.store.setPreference(item.text, value: toggle.isOn) }
            }, for: .valueChanged)
            content.addSubview(toggle)
        }
    }
    private func installUtilityControls() {
        if screen.id == "S01" {
            let button = UIButton(type: .custom); button.frame = CGRect(x: screen.width-70,y: 48,width: 62,height: 58)
            button.accessibilityLabel = "Create space"; button.accessibilityIdentifier = "space.create"
            button.addAction(UIAction { [weak self] _ in self?.coordinator.createSpace() }, for: .touchUpInside); content.addSubview(button)
        }
        if !ScreenRoutes.roots.contains(screen.id) {
            let back = UIButton(type: .system)
            back.frame = CGRect(x: 8, y: screen.top, width: 36, height: 38)
            back.backgroundColor = UIColor(rgb: screen.background)
            back.setImage(UIImage(systemName: "chevron.left"), for: .normal); back.tintColor = .label
            back.accessibilityLabel = "Back"; back.accessibilityIdentifier = "navigation.back"
            back.addAction(UIAction { [weak self] _ in self?.coordinator.back() }, for: .touchUpInside)
            content.addSubview(back)
        }
        if ["D01", "P01", "C01"].contains(screen.id) {
            addAction(CGRect(x: screen.width-47,y: 44,width: 42,height: 42), name: screen.id == "P01" ? "Settings" : "Activity", action: screen.id == "P01" ? "P05" : "P03")
        }
        if screen.id == "P01" { addAction(CGRect(x: screen.width-90,y: 44,width: 40,height: 42), name: "Saved", action: "P02") }
        if screen.id == "C03" {
            addAction(CGRect(x: screen.width-48,y: 46,width: 44,height: 36), name: "Post options", action: "@postMenu")
            addAction(CGRect(x: screen.width-45,y: 449,width: 36,height: 32), name: "Save post", action: "@save")
        }
        if screen.id == "C01" { addAction(CGRect(x: 10,y: 82,width: 55,height: 36), name: "Circles", action: "C07") }
        #if DEBUG
        let inspect = UILongPressGestureRecognizer(target: self, action: #selector(showCatalog(_:)))
        inspect.minimumPressDuration = 1.2; inspect.cancelsTouchesInView = false; view.addGestureRecognizer(inspect)
        #endif
    }
    @objc private func showCatalog(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began { coordinator.showCatalog() }
    }
    private func refreshState() {
        if screen.id == "M01" { refreshProjectCards() }
        refreshLocalLists()
        let project = coordinator.currentProject
        for (item, label) in labels {
            if ["M03","M04","M05"].contains(screen.id), let project {
                if item.text == "Woven wall hanging" { label.text = project.name }
                if item.text.contains("of 6") { label.text = "\(project.completedSteps) of \(project.totalSteps) steps" }
            }
            if screen.id == "M04", let project {
                let index = min(project.completedSteps, 5)
                let titles = ["Cut your cords", "Prepare the dowel", "Tie the first row", "Add more rows", "Trim the fringe", "Finish and hang"]
                let instructions = ["Measure and cut six equal lengths of cotton cord.", "Place your dowel on a flat surface and mark even spacing.", "Fold each cord in half and attach it to the dowel.", "Work across the row, keeping the knots evenly spaced.", "Comb out the fringe and trim to your preferred shape.", "Add a hanging cord and place your finished weave."]
                if item.text == "Tie the first row" { label.text = titles[index] }
                if item.text.hasPrefix("Create a row") { label.text = instructions[index] }
                if item.text.first?.isNumber == true && item.text.contains(". ") { label.isHidden = true }
            }
            if screen.id == "P04", item.text == "Username is available" { label.text = "Stored on this device" }
            if screen.id == "P08", item.text == "maya@example.com" { label.text = "No online account connected" }
            if screen.id == "P01", item.text == "48" { label.text = "\(coordinator.store.state.projects.count)" }
            if screen.id == "P01", item.text == "12" { label.text = "\(coordinator.store.state.spaces.count)" }
            if screen.id == "P01", item.text == "1.2K" { label.text = "0" }
            if screen.id == "P01", item.text == "Maya Chen" { label.text = coordinator.store.state.profileName }
            if item.text == "Follow" { label.text = coordinator.store.state.following.contains("Nora") ? "Following" : "Follow" }
            if screen.id == "C03", item.text == "482" { label.text = coordinator.store.state.likes.contains("C03") ? "483" : "482" }
        }
        if screen.id == "S03" {
            textFields["space"]?.text = coordinator.isCreatingSpace ? "" : coordinator.selectedSpace
            textFields["spaceNotes"]?.text = coordinator.store.state.spaceDetails?[coordinator.selectedSpace]?.notes ?? ""
        }
        if screen.id == "P10" { textFields["collection"]?.text = "" }
        if screen.id == "M07" { textFields["name"]?.text = project?.name }
        if screen.id == "M06" { textFields["note"]?.text = project?.notes.isEmpty == false ? project?.notes : "" }
        if screen.id == "P04" { textFields["name"]?.text = coordinator.store.state.profileName; textFields["bio"]?.text = coordinator.store.state.biography }
        if screen.id == "C02", let draft = coordinator.store.state.draft { textFields["title"]?.text = draft.title; textFields["body"]?.text = draft.body }
    }
    private func refreshProjectCards() {
        minimumContentHeight = max(screen.height, 280+CGFloat(coordinator.store.state.projects.count)*146)
        projectCards.forEach { $0.removeFromSuperview() }; projectCards.removeAll()
        // Replace sample project records with the user's persisted projects.
        for subview in content.subviews where !(subview is SurfaceView) && subview.frame.minY > 258 { subview.isHidden = true }
        let cover = UIView(frame: CGRect(x: 0, y: 258, width: screen.width, height: max(screen.height, CGFloat(coordinator.store.state.projects.count)*146+280)-258))
        cover.backgroundColor = .roomCream; content.addSubview(cover); projectCards.append(cover)
        for (index, project) in coordinator.store.state.projects.filter { !(coordinator.store.state.archivedProjects?.contains($0.id) ?? false) }.enumerated() {
            let card = UIButton(type: .custom)
            card.frame = CGRect(x: 16, y: 270+CGFloat(index)*146, width: screen.width-32, height: 130)
            card.backgroundColor = .white; card.layer.cornerRadius = 18; card.clipsToBounds = true
            if let image = screen.images.first(where: { $0.name.contains("media") && $0.box[2]>80 }) {
                let photo = UIImageView(image: DesignCatalog.image(image.name)); photo.frame = CGRect(x: 0,y: 0,width: 112,height: 130); photo.contentMode = .scaleAspectFill; photo.clipsToBounds = true; card.addSubview(photo)
            }
            let title = UILabel(frame: CGRect(x: 124,y: 17,width: card.bounds.width-136,height: 45)); title.text = project.name; title.font = .systemFont(ofSize: 16, weight: .semibold); title.numberOfLines = 2; card.addSubview(title)
            let progress = UILabel(frame: CGRect(x: 124,y: 71,width: card.bounds.width-136,height: 22)); progress.text = "\(project.completedSteps) of \(project.totalSteps) steps"; progress.font = .systemFont(ofSize: 12); progress.textColor = .secondaryLabel; card.addSubview(progress)
            let bar = UIProgressView(progressViewStyle: .default); bar.frame = CGRect(x: 124,y: 109,width: card.bounds.width-140,height: 4); bar.progressTintColor = .roomGreen; bar.progress = Float(project.completedSteps)/Float(project.totalSteps); card.addSubview(bar)
            card.accessibilityLabel = project.name; card.accessibilityIdentifier = "project.\(project.id)"
            card.addAction(UIAction { [weak self] _ in self?.coordinator.openProject(project.id) }, for: .touchUpInside)
            content.addSubview(card); projectCards.append(card)
        }
    }
    func refresh() { refreshState() }
}
