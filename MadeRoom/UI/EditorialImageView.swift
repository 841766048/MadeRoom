import UIKit
import CryptoKit

struct EditorialImageRecord: Decodable {
    let id: String
    let sha256: String
    let downloadURL: String?
}
enum EditorialImageCatalog {
    private struct Manifest: Decodable { let images: [EditorialImageRecord] }
    static private(set) var records: [String: EditorialImageRecord] = [:]
    static let manifestURL = URL(string: "https://made-room-20261009.web.app/catalog/image-manifest.json")!
    private static var pending: [(Bool) -> Void] = []
    private static var fetching = false
    static func decodeManifest(_ data: Data) throws -> [String: EditorialImageRecord] {
        let images = try JSONDecoder().decode(Manifest.self, from: data).images
        guard !images.isEmpty, Set(images.map(\.id)).count == images.count,
              images.allSatisfy({ !$0.id.isEmpty && $0.sha256.count == 64 && URL(string:$0.downloadURL ?? "")?.scheme == "https" && URL(string:$0.downloadURL ?? "")?.host == "made-room-20261009.web.app" }) else { throw CocoaError(.fileReadCorruptFile) }
        return Dictionary(uniqueKeysWithValues: images.map { ($0.id, $0) })
    }
    static func fetch(_ completion: @escaping (Bool) -> Void) {
        if !records.isEmpty { completion(true); return }
        pending.append(completion)
        guard !fetching else { return }; fetching = true
        let request = URLRequest(url:manifestURL, cachePolicy:.useProtocolCachePolicy, timeoutInterval:20)
        URLSession.shared.dataTask(with:request) { data, response, error in
            let decoded = error == nil && (response as? HTTPURLResponse)?.statusCode == 200 ? data.flatMap { try? decodeManifest($0) } : nil
            DispatchQueue.main.async {
                if let decoded { records = decoded }
                fetching = false; let callbacks = pending; pending.removeAll()
                callbacks.forEach { $0(decoded != nil) }
            }
        }.resume()
    }
    static let cache = NSCache<NSString, UIImage>()
}
final class EditorialImageView: UIImageView {
    private let asset: String
    private let fallbackImage: UIImage?
    private let showsGlobalLoading: Bool
    private var waitingForManifest = false
    private var task: URLSessionDataTask?
    private var loadingTicket: NetworkLoadingTicket?
    init(asset: String, fallbackImage: UIImage? = nil, showsGlobalLoading: Bool = true) {
        self.asset = asset; self.fallbackImage = fallbackImage; self.showsGlobalLoading = showsGlobalLoading
        super.init(frame: .zero)
        isUserInteractionEnabled = true
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(load)))
        load()
    }
    required init?(coder: NSCoder) { fatalError("init(asset:)") }
    deinit { task?.cancel(); loadingTicket?.finish() }
    @objc private func load() {
        guard task == nil, !waitingForManifest else { return }
        if let local = DesignCatalog.image(asset) { image = local; return }
        if let cached = EditorialImageCatalog.cache.object(forKey: asset as NSString) { image = cached; return }
        image = fallbackImage ?? UIImage(systemName: "photo")
        tintColor = .secondaryLabel
        accessibilityLabel = "Image loading"
        if EditorialImageCatalog.records.isEmpty {
            waitingForManifest = true
            EditorialImageCatalog.fetch { [weak self] success in
                guard let self else { return }; self.waitingForManifest = false
                if success { self.load() }
                else { self.accessibilityLabel = "Image unavailable. Double tap to retry." }
            }
            return
        }
        guard let record = EditorialImageCatalog.records[asset], let address = record.downloadURL,
              let url = URL(string: address), url.scheme == "https", url.host == "made-room-20261009.web.app" else { return }
        let placeholder = image
        var request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 30)
        request.httpMethod = "GET"
        let loading = showsGlobalLoading ? NetworkLoading.shared.begin() : nil
        loadingTicket = loading
        task = URLSession.shared.dataTask(with: request) { [weak self] data, response, _ in
            var downloaded: UIImage?
            if let data, data.count <= 20_000_000, (response as? HTTPURLResponse)?.statusCode == 200,
               SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == record.sha256 {
                downloaded = UIImage(data: data)
            }
            DispatchQueue.main.async {
                defer { loading?.finish() }
                guard let self else { return }
                self.task = nil
                // Do not overwrite an explicitly selected user photo.
                guard self.image === placeholder else { return }
                if let downloaded {
                    EditorialImageCatalog.cache.setObject(downloaded, forKey: self.asset as NSString, cost: Int(downloaded.size.width * downloaded.size.height * 4))
                    self.image = downloaded; self.accessibilityLabel = nil
                } else { self.accessibilityLabel = "Image unavailable. Double tap to retry." }
            }
        }
        task?.resume()
    }
}
