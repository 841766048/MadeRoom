import UIKit
import FirebaseFirestore

/// A semantic route index. It contains no OCR coordinates, image regions or screenshot geometry.
struct DesignScreen { let id: String; let name: String }
final class DesignCatalog {
    let screens: [DesignScreen]
    init() throws {
        let groups: [(String,[String])] = [
            ("D",["Discover","Search","Collection","Tutorial"]),
            ("M",["Make","Start project","Project","Guided step","Finish project","Project notes","Edit project"]),
            ("S",["Spaces","Space detail","Edit space","Arrange plan","Add a piece"]),
            ("C",["Community","Publish","Post","Comments","Maker","Connections","Circles","Circle","Challenge","Try this make","Submit make","Circle guidelines","Edit post"]),
            ("P",["Profile","Saved","Activity","Edit profile","Settings","Privacy","Notifications","Account","Saved collection","Collection editor","Preferences"]),
            ("A",["Welcome","Sign in","Interests"]),
            ("X",["Report","Empty","Offline","Photo access","Publish retry","Form errors","Saved result","Content unavailable","Moderation","Sync conflict","Delete make","Search empty","Challenge result"])]
        screens = groups.flatMap { prefix,names in names.enumerated().map { DesignScreen(id: String(format:"%@%02d",prefix,$0.offset+1),name:$0.element) } }
    }
    subscript(_ id: String) -> DesignScreen? { screens.first { $0.id == id } }
    static func image(_ name: String) -> UIImage? {
        guard let url = Bundle.main.url(forResource:name,withExtension:"png",subdirectory:"EditorialAssets") else { return nil }
        return UIImage(contentsOfFile:url.path)
    }
}
extension UIColor {
    static let roomGreen = UIColor(red:0.25,green:0.39,blue:0.27,alpha:1)
    static let roomCream = UIColor(red:0.978,green:0.974,blue:0.961,alpha:1)
    static let roomYellow = UIColor(red:0.97,green:0.85,blue:0.43,alpha:1)
}

struct CraftKnowledge: Codable {
    struct Source: Codable { let url: String }
    let sources: [Source]
    let id: String
    let title: String
    let summary: String
    let language: String
    let imageIds: [String]
    let materials: [String]
    let steps: [String]
    let tips: [String]
}
/// Editorial copy remains English regardless of the surrounding app language.
final class KnowledgeLibraryController: UITableViewController {
    var openComments: ((CraftKnowledge) -> Void)?
    private var items: [CraftKnowledge] = []
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Craft Library"
        let label = UILabel(); label.text = "Loading craft library…"; label.textAlignment = .center; tableView.backgroundView = label
        tableView.backgroundColor = .roomCream
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(refreshKnowledge), for: .valueChanged)
        refreshKnowledge()
    }
    @objc private func refreshKnowledge() {
        let loading = NetworkLoading.shared.begin()
        CommentDatabase.shared.collection("knowledge").order(by: "catalogOrder").limit(to: 100)
            .getDocuments(source: .server) { [weak self] snapshot, error in
                defer { loading.finish() }
                guard let self else { return }
                self.refreshControl?.endRefreshing()
                do {
                    guard let snapshot, error == nil else {
                        throw error ?? CocoaError(.fileReadUnknown)
                    }
                    let remote = try snapshot.documents.map { try $0.data(as: CraftKnowledge.self) }
                    guard remote.allSatisfy({ $0.language == "en" && !$0.title.isEmpty }),
                          Set(remote.map(\.id)).count == remote.count else { throw CocoaError(.fileReadCorruptFile) }
                    self.items = remote
                    self.tableView.backgroundView = nil
                    if remote.isEmpty { let label = UILabel(); label.text = "No articles yet."; label.textAlignment = .center; self.tableView.backgroundView = label }
                    self.navigationItem.prompt = "Updated from cloud"
                    self.tableView.reloadData()
                } catch {
                    self.navigationItem.prompt = "Could not update · Pull to retry"
                    if self.items.isEmpty { let label = UILabel(); label.text = "Could not load the craft library. Pull down to retry."; label.numberOfLines = 0; label.textAlignment = .center; self.tableView.backgroundView = label }
                }
            }
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { items.count }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        let item = items[indexPath.row]
        let title = RoomUI.label(item.title, size: 17, weight: .semibold)
        title.text = item.title
        let summary = RoomUI.label(item.summary, size: 13, color: .secondaryLabel)
        summary.text = item.summary
        summary.numberOfLines = 3
        let row = RoomUI.stack(axis: .horizontal, spacing: 14)
        row.alignment = .center
        if let cover = item.imageIds.first {
            let image = RoomUI.image(cover, ratio: 1, radius: 12)
            image.widthAnchor.constraint(equalToConstant: 88).isActive = true
            row.addArrangedSubview(image)
        }
        row.addArrangedSubview(RoomUI.stack([title, summary], spacing: 6))
        cell.contentView.addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 14),
            row.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -14),
            row.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 20),
            row.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -8)
        ])
        cell.accessoryType = .disclosureIndicator
        cell.backgroundColor = .roomCream
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = items[indexPath.row]
        tableView.deselectRow(at: indexPath, animated: true)
        let view = KnowledgeDetailController(item: item)
        view.openComments = openComments
        navigationController?.pushViewController(view, animated: true)
    }
}

/// Uses the community post's image, typography, spacing and action layout.
final class KnowledgeDetailController: UIViewController {
    let item: CraftKnowledge
    var openComments: ((CraftKnowledge) -> Void)?
    init(item: CraftKnowledge) {
        self.item = item
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }
    required init?(coder: NSCoder) { fatalError("init(item:)") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Made Room"
        view.backgroundColor = .roomCream
        view.accessibilityIdentifier = "knowledge.detail"
        let scroll = UIScrollView()
        let body = RoomUI.stack(spacing: 14)
        view.addSubview(scroll); scroll.addSubview(body)
        scroll.translatesAutoresizingMaskIntoConstraints = false
        body.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            body.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 8),
            body.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            body.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 20),
            body.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -20),
            body.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -40)
        ])
        if let cover = item.imageIds.first {
            body.addArrangedSubview(RoomUI.image(cover, ratio: 1.02))
        }
        body.addArrangedSubview(copy(item.title, size: 30, weight: .bold))
        body.addArrangedSubview(copy("Craft Library · Made Room", size: 13, color: .secondaryLabel))
        body.addArrangedSubview(copy(item.summary, size: 16))
        let comments = RoomUI.button("Comments", icon: "bubble.left") { [weak self] in
            guard let self else { return }; self.openComments?(self.item)
        }
        comments.configuration?.title = "Comments"
        comments.accessibilityIdentifier = "knowledge.comments"
        let share = RoomUI.button("Share", icon: "square.and.arrow.up") { [weak self] in self?.share() }
        share.configuration?.title = "Share"
        share.accessibilityIdentifier = "knowledge.share"
        let actions = RoomUI.stack([comments, share], axis: .horizontal)
        actions.distribution = .fillEqually
        body.addArrangedSubview(actions)
        section("Materials", entries: item.materials.map { "• " + $0 }, in: body)
        section("Steps", entries: item.steps.enumerated().map { "\($0.offset + 1). \($0.element)" }, in: body)
        section("Tips", entries: item.tips.map { "• " + $0 }, in: body)
        if item.imageIds.count > 1 {
            body.addArrangedSubview(copy("More details", size: 20, weight: .bold))
            for asset in item.imageIds.dropFirst() {
                let image = RoomUI.image(asset, ratio: 0.8)
                image.contentMode = .scaleAspectFit
                body.addArrangedSubview(image)
            }
        }
        let sources = item.sources.compactMap { URL(string: $0.url) }.filter { $0.scheme == "https" && $0.host != nil }
        if !sources.isEmpty {
            body.addArrangedSubview(RoomUI.divider())
            body.addArrangedSubview(copy("Sources", size: 20, weight: .bold))
            for url in sources {
                let title = "Read source · " + (url.host ?? "Reference")
                let button = RoomUI.button(title, icon: "arrow.up.right") { UIApplication.shared.open(url) }
                button.configuration?.title = title
                button.contentHorizontalAlignment = .leading
                body.addArrangedSubview(button)
            }
        }
    }
    private func copy(_ text: String, size: CGFloat, weight: UIFont.Weight = .regular, color: UIColor = .label) -> UILabel {
        let label = RoomUI.label(text, size: size, weight: weight, color: color)
        label.text = text // Knowledge editorial copy always remains English.
        return label
    }
    private func section(_ title: String, entries: [String], in body: UIStackView) {
        guard !entries.isEmpty else { return }
        body.addArrangedSubview(RoomUI.divider())
        body.addArrangedSubview(copy(title, size: 20, weight: .bold))
        entries.forEach { body.addArrangedSubview(copy($0, size: 16)) }
    }
    private func share() {
        let sheet = UIActivityViewController(activityItems: [item.title + "\n\n" + item.summary], applicationActivities: nil)
        sheet.popoverPresentationController?.sourceView = view
        sheet.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        present(sheet, animated: true)
    }
}
