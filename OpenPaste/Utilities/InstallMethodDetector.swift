import Foundation

enum InstallMethodDetector {
    static func detect(bundleURL: URL = Bundle.main.bundleURL) -> FeedbackInstallMethod {
        let path = bundleURL.path.lowercased()

        if path.contains("/caskroom/") {
            return .homebrew
        }

        if path.contains("deriveddata") || path.contains("/build/") || path.contains("/sourcepackages/") {
            return .buildFromSource
        }

        if path.hasPrefix("/applications/") {
            return .dmg
        }

        return .other
    }
}