import UIKit

final class TextEditorController: UIViewController {
    private let editor = UITextView()
    private let initial: String
    private let save: (String)->Void
    init(title: String, value: String, save: @escaping (String)->Void) {
        initial = value; self.save = save; super.init(nibName: nil, bundle: nil); self.title = AppLanguage.text(title)
    }
    required init?(coder: NSCoder) { fatalError("Use designated initializer") }
    override func viewDidLoad() {
        super.viewDidLoad(); view.backgroundColor = .roomCream
        editor.text = initial; editor.font = .preferredFont(forTextStyle: .body); editor.adjustsFontForContentSizeCategory = true
        editor.backgroundColor = .clear; editor.translatesAutoresizingMaskIntoConstraints = false
        editor.accessibilityIdentifier = "editor.body"; view.addSubview(editor)
        NSLayoutConstraint.activate([editor.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20), editor.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20), editor.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16), editor.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -16)])
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: AppLanguage.text("Cancel"), primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) })
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: AppLanguage.text("Save"), primaryAction: UIAction { [weak self] _ in
            guard let self else { return }; let text = self.editor.text ?? ""
            self.dismiss(animated: true) { self.save(text) }
        })
        editor.becomeFirstResponder()
    }
}
final class CatalogController: UITableViewController {
    let screens: [DesignScreen]
    let select: (String)->Void
    init(screens: [DesignScreen], select: @escaping (String)->Void) { self.screens = screens.sorted { $0.id < $1.id }; self.select = select; super.init(style: .insetGrouped) }
    required init?(coder: NSCoder) { fatalError("Use designated initializer") }
    override func viewDidLoad() {
        super.viewDidLoad(); title = AppLanguage.text("Design review · 56 layouts")
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: AppLanguage.text("Close"), primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) })
        let header = UILabel(frame: CGRect(x: 20,y: 0,width: 330,height: 80)); header.numberOfLines = 0; header.font = .preferredFont(forTextStyle: .footnote)
        header.text = AppLanguage.text("Development preview. Success, error and cloud states are examples, not live service responses.")
        tableView.tableHeaderView = header
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { screens.count }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil); let s = screens[indexPath.row]
        cell.textLabel?.text = "\(s.id) · \(AppLanguage.text(s.name))"; cell.detailTextLabel?.text = AppLanguage.text("Native UIKit layout"); cell.accessoryType = .disclosureIndicator; return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) { select(screens[indexPath.row].id) }
}
