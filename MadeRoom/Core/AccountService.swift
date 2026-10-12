import FirebaseCore
import FirebaseAuth

/// A separate Firebase app name keeps emulator credentials out of the real session.
enum AccountService {
    static let auth: Auth = {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--auth-emulator") {
            let options = FirebaseApp.app()!.options
            FirebaseApp.configure(name: "MadeRoomAuthEmulator", options: options)
            let auth = Auth.auth(app: FirebaseApp.app(name: "MadeRoomAuthEmulator")!)
            auth.useEmulator(withHost: "127.0.0.1", port: 9098)
            return auth
        }
        #endif
        return Auth.auth()
    }()
}
