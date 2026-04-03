import Testing
@testable import OpenPaste

@Suite(.serialized)
struct FeedbackViewModelTests {
    private let metadata = FeedbackMetadata(
        appVersion: "1.2.3",
        macOSVersion: "macOS 15.4",
        installMethod: .dmg
    )

    @Test @MainActor func submitRequiresAllCoreFields() {
        let viewModel = FeedbackViewModel(router: FeedbackRouter(), metadata: metadata)

        #expect(!viewModel.canSubmit)

        viewModel.summary = "Clipboard history feels great"
        viewModel.workflow = "I was jumping between Terminal and Xcode."
        viewModel.expectedHelp = "I wanted to recall a previous command quickly."
        viewModel.actualResult = "It was easy to find and paste."

        #expect(viewModel.canSubmit)
    }

    @Test @MainActor func categorySwitchChangesDestinationLabel() {
        let viewModel = FeedbackViewModel(router: FeedbackRouter(), metadata: metadata)

        viewModel.category = .bug
        #expect(viewModel.submitTitle == "Open in GitHub")

        viewModel.category = .praise
        #expect(viewModel.submitTitle == "Open in Mail")
    }

    @Test @MainActor func metadataComesFromInitialization() {
        let viewModel = FeedbackViewModel(router: FeedbackRouter(), metadata: metadata)

        #expect(viewModel.appVersion == "1.2.3")
        #expect(viewModel.macOSVersion == "macOS 15.4")
        #expect(viewModel.installMethod == .dmg)
    }

    @Test @MainActor func resetClearsUserInputAndRestoresDefaults() {
        let viewModel = FeedbackViewModel(router: FeedbackRouter(), metadata: metadata)

        viewModel.category = .feature
        viewModel.installMethod = .other
        viewModel.summary = "Need snippets"
        viewModel.workflow = "I keep reusing support replies."
        viewModel.expectedHelp = "Pinned text snippets would help."
        viewModel.actualResult = "I currently search history and rewrite them."
        viewModel.blockers = "It’s repetitive."
        viewModel.publicQuoteAllowed = true
        viewModel.publicQuote = "This saves me real time every day."

        viewModel.reset()

        #expect(viewModel.category == .workflow)
        #expect(viewModel.installMethod == .dmg)
        #expect(viewModel.summary.isEmpty)
        #expect(viewModel.workflow.isEmpty)
        #expect(viewModel.expectedHelp.isEmpty)
        #expect(viewModel.actualResult.isEmpty)
        #expect(viewModel.blockers.isEmpty)
        #expect(!viewModel.publicQuoteAllowed)
        #expect(viewModel.publicQuote.isEmpty)
    }
}