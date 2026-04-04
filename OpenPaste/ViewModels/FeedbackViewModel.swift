import Foundation

@MainActor
@Observable
final class FeedbackViewModel {
    var category: FeedbackCategory
    var installMethod: FeedbackInstallMethod
    var summary = ""
    var workflow = ""
    var expectedHelp = ""
    var actualResult = ""
    var blockers = ""
    var publicQuoteAllowed = false
    var publicQuote = ""

    let appVersion: String
    let macOSVersion: String

    @ObservationIgnored private let router: FeedbackRouterProtocol
    @ObservationIgnored private let defaultMetadata: FeedbackMetadata

    init(router: FeedbackRouterProtocol, metadata: FeedbackMetadata = .current()) {
        self.router = router
        defaultMetadata = metadata
        category = .workflow
        installMethod = metadata.installMethod
        appVersion = metadata.appVersion
        macOSVersion = metadata.macOSVersion
    }

    var destination: FeedbackDestination {
        router.destination(for: draft)
    }

    var submitTitle: String {
        "Open in \(destination.label)"
    }

    var canSubmit: Bool {
        [summary, workflow, expectedHelp, actualResult].allSatisfy {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    var draft: FeedbackDraft {
        FeedbackDraft(
            category: category,
            summary: summary,
            workflow: workflow,
            expectedHelp: expectedHelp,
            actualResult: actualResult,
            blockers: blockers,
            publicQuoteAllowed: publicQuoteAllowed,
            publicQuote: publicQuote,
            metadata: FeedbackMetadata(
                appVersion: appVersion,
                macOSVersion: macOSVersion,
                installMethod: installMethod
            )
        )
    }

    func reset() {
        category = .workflow
        installMethod = defaultMetadata.installMethod
        summary = ""
        workflow = ""
        expectedHelp = ""
        actualResult = ""
        blockers = ""
        publicQuoteAllowed = false
        publicQuote = ""
    }
}