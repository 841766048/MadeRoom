import UIKit

/// One presentation for overlapping requests. Expiry only ends the visual wait, never reports success.
final class NetworkLoading {
    static let shared = NetworkLoading()
    private let overlay = RequestLoadingView()
    private weak var host: UIView?
    private var requests: Set<UUID> = []
    var activeCount: Int { requests.count }
    func attach(to host: UIView) {
        self.host = host
        if !requests.isEmpty { present() }
    }
    func begin(timeout: TimeInterval = 30) -> NetworkLoadingTicket {
        precondition(Thread.isMainThread)
        let id = UUID()
        requests.insert(id)
        if requests.count == 1 { present() }
        let ticket = NetworkLoadingTicket { [weak self] in self?.finish(id) }
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak ticket] in ticket?.finish() }
        return ticket
    }
    private func present() {
        guard let host else { return }
        // The full-window shield consumes touches until all visible waits finish.
        overlay.isUserInteractionEnabled = true
        overlay.accessibilityViewIsModal = true
        overlay.show(in: host)
    }
    private func finish(_ id: UUID) {
        requests.remove(id)
        if requests.isEmpty { overlay.dismiss() }
    }
}

/// Idempotent and thread-safe: callbacks, cancellation and deallocation can all finish a ticket.
final class NetworkLoadingTicket {
    private let lock = NSLock()
    private var completion: (() -> Void)?
    init(completion: @escaping () -> Void) { self.completion = completion }
    func finish() {
        lock.lock(); let callback = completion; completion = nil; lock.unlock()
        guard let callback else { return }
        if Thread.isMainThread { callback() } else { DispatchQueue.main.async(execute: callback) }
    }
    deinit { finish() }
}
