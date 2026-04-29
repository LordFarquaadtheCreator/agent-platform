import Foundation

// MARK: - AppVersion
// Shared app version identifier for OAuth callback routing.
// Prevents wrong app version from processing OAuth callbacks.

public enum AppVersion {
    public static var identifier: String {
        let info = Bundle.main
        let version = info.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let build = info.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(version)-\(build)"
    }
}
