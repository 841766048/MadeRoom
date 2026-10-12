import Foundation

/// App-container marker disappears on uninstall, unlike Firebase's Keychain session.
enum InstallationSession {
    static func prepare(marker: URL, signOut: () throws -> Void, resetConsent: () -> Void) throws {
        guard !FileManager.default.fileExists(atPath: marker.path) else { return }
        try signOut() // Never mark an installation initialized if Keychain cleanup failed.
        resetConsent()
        try FileManager.default.createDirectory(at: marker.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("1".utf8).write(to: marker, options: .atomic)
        var url = marker
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try url.setResourceValues(values)
    }
}
