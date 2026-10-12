import UIKit
import FirebaseCore
import FirebaseAuth
import IQKeyboardManagerSwift
import IQKeyboardToolbarManager

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    static var installationError: Error?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let keyboard = IQKeyboardManager.shared
        keyboard.isEnabled = true
        keyboard.keyboardDistance = 12
        keyboard.resignOnTouchOutside = true
        // Full-screen text editors already size their text view with keyboardLayoutGuide.
        keyboard.disabledDistanceHandlingClasses.append(TextEditorController.self)
        // Existing custom accessory views are preserved by the toolbar manager.
        IQKeyboardToolbarManager.shared.isEnabled = true
        IQKeyboardToolbarManager.shared.toolbarConfiguration.tintColor = .roomGreen
        FirebaseApp.configure()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--reset-test-state") && ProcessInfo.processInfo.arguments.contains("--uitesting") { try? AccountService.auth.signOut() }
        #endif
        do {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            let test = ProcessInfo.processInfo.arguments.contains("--auth-emulator")
            let marker = base.appendingPathComponent(test ? "test-installation-v1" : "installation-v1")
            #if DEBUG
            if test && ProcessInfo.processInfo.arguments.contains("--uitesting") && ProcessInfo.processInfo.arguments.contains("--simulate-reinstall") {
                try? FileManager.default.removeItem(at: marker)
                try? FileManager.default.removeItem(at: base.appendingPathComponent("MadeRoomTestUsers"))
            }
            #endif
            try InstallationSession.prepare(marker: marker, signOut: { try AccountService.auth.signOut() }, resetConsent: { AuthConsent.reset() })
        } catch { Self.installationError = error }
        return true
    }
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Made Room", sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var coordinator: AppCoordinator?
    func sceneDidBecomeActive(_ scene: UIScene) { coordinator?.comments?.flush(); coordinator?.profile?.flush(); coordinator?.spacesSync?.flush(); coordinator?.librarySync?.flush() }
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: scene); self.window = window
        window.overrideUserInterfaceStyle = .light
        NetworkLoading.shared.attach(to: window)
        do {
            if let error = AppDelegate.installationError { throw error }
            let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("MadeRoom")
            let file = ProcessInfo.processInfo.arguments.contains("--uitesting") ? "uitest-state.json" : "state.json"
            let url = directory.appendingPathComponent(file)
            if ProcessInfo.processInfo.arguments.contains("--reset-test-state") { try? FileManager.default.removeItem(at: url) }
            let store = try RoomStore(url: url)
            let coordinator = AppCoordinator(store: store, catalog: try DesignCatalog()); self.coordinator = coordinator
            coordinator.start(in: window)
        } catch {
            let vc = UIViewController(); vc.view.backgroundColor = .roomCream
            let label = UILabel(); label.numberOfLines = 0; label.textAlignment = .center
            label.text = "Made Room couldn't open your local data.\n\nYour file has been preserved.\n\n\(error.localizedDescription)"
            label.translatesAutoresizingMaskIntoConstraints = false; vc.view.addSubview(label)
            NSLayoutConstraint.activate([label.centerYAnchor.constraint(equalTo: vc.view.centerYAnchor), label.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor, constant: 24), label.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor, constant: -24)])
            window.rootViewController = vc; window.makeKeyAndVisible()
        }
    }
}
