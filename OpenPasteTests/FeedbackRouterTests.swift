import Foundation
import Testing
@testable import OpenPaste

struct FeedbackRouterTests {
    private let router = FeedbackRouter()
    private let metadata = FeedbackMetadata(
        appVersion: "1.2.3",
        macOSVersion: "macOS 15.4",
        installMethod: .homebrew
    )

    @Test func bugFeedbackOpensGitHubFeedbackForm() throws {
        let draft = FeedbackDraft(
            category: .bug,
            summary: "Paste sends stale content",
            workflow: "Copied a JSON payload from Postman and pasted from OpenPaste.",
            expectedHelp: "I expected the latest payload to paste back into VS Code.",
            actualResult: "It pasted an older clipboard item instead.",
            blockers: "I stopped trusting the history order.",
            publicQuoteAllowed: false,
            publicQuote: "",
            metadata: metadata
        )

        let destination = router.destination(for: draft)
        let components = try #require(URLComponents(url: destination.url, resolvingAgainstBaseURL: false))
        let template = components.queryItems?.first(where: { $0.name == "template" })?.value
        let title = components.queryItems?.first(where: { $0.name == "title" })?.value
        let workflow = components.queryItems?.first(where: { $0.name == "workflow" })?.value
        let installMethod = components.queryItems?.first(where: { $0.name == "install-method" })?.value

        #expect(destination.label == "GitHub")
        #expect(destination.url.absoluteString.contains("github.com/openpaste/openpaste/issues/new"))
        #expect(template == "feedback.yml")
        #expect(title == "[Bug] Paste sends stale content")
        #expect(installMethod == "Homebrew")
        #expect(workflow?.contains("Feedback type: Bug Report") == true)
    }

    @Test func praiseFeedbackOpensMailDraft() throws {
        let draft = FeedbackDraft(
            category: .praise,
            summary: "Search feels instant",
            workflow: "I was digging up shell commands copied earlier in the day.",
            expectedHelp: "I wanted to find them without breaking focus.",
            actualResult: "OpenPaste got me back to work in seconds.",
            blockers: "",
            publicQuoteAllowed: true,
            publicQuote: "OpenPaste feels like the clipboard manager I wanted years ago.",
            metadata: metadata
        )

        let destination = router.destination(for: draft)
        let components = try #require(URLComponents(url: destination.url, resolvingAgainstBaseURL: false))
        let subject = components.queryItems?.first(where: { $0.name == "subject" })?.value
        let body = components.queryItems?.first(where: { $0.name == "body" })?.value

        #expect(destination.label == "Mail")
        #expect(destination.url.scheme == "mailto")
        #expect(subject == "[Praise] Search feels instant")
        #expect(body?.contains("Can we quote your positive feedback publicly?** Yes") == true)
        #expect(body?.contains("OpenPaste feels like the clipboard manager I wanted years ago.") == true)
    }

    @Test func workflowFeedbackMarksQuotePermissionAsNo() throws {
        let draft = FeedbackDraft(
            category: .workflow,
            summary: "Search ranking felt odd",
            workflow: "I searched for a prompt snippet copied this morning.",
            expectedHelp: "I expected the freshest result to appear first.",
            actualResult: "An older clip was easier to find than the new one.",
            blockers: "",
            publicQuoteAllowed: true,
            publicQuote: "",
            metadata: metadata
        )

        let destination = router.destination(for: draft)
        let components = try #require(URLComponents(url: destination.url, resolvingAgainstBaseURL: false))
        let quotePermission = components.queryItems?.first(where: { $0.name == "quote-permission" })?.value
        let quote = components.queryItems?.first(where: { $0.name == "quote" })?.value

        #expect(quotePermission == "No")
        #expect(quote == "")
    }
}