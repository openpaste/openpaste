import Foundation

enum FeedbackInstallMethod: String, CaseIterable, Identifiable, Sendable {
    case homebrew = "Homebrew"
    case dmg = "DMG / GitHub Release"
    case buildFromSource = "Build from source"
    case other = "Other"

    var id: String { rawValue }
}

struct FeedbackMetadata: Equatable, Sendable {
    var appVersion: String
    var macOSVersion: String
    var installMethod: FeedbackInstallMethod

    static func current(
        bundle: Bundle = .main,
        processInfo: ProcessInfo = .processInfo,
        bundleURL: URL = Bundle.main.bundleURL
    ) -> FeedbackMetadata {
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let operatingSystem = processInfo.operatingSystemVersionString
            .replacingOccurrences(of: "Version ", with: "macOS ")

        return FeedbackMetadata(
            appVersion: version,
            macOSVersion: operatingSystem,
            installMethod: InstallMethodDetector.detect(bundleURL: bundleURL)
        )
    }
}

struct FeedbackDraft: Equatable, Sendable {
    var category: FeedbackCategory = .workflow
    var summary = ""
    var workflow = ""
    var expectedHelp = ""
    var actualResult = ""
    var blockers = ""
    var publicQuoteAllowed = false
    var publicQuote = ""
    var metadata: FeedbackMetadata = .current()
}