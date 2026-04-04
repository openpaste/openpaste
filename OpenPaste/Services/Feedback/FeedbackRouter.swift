import Foundation

struct FeedbackRouter: FeedbackRouterProtocol {
    func destination(for draft: FeedbackDraft) -> FeedbackDestination {
        switch draft.category {
        case .praise:
            mailDestination(for: draft)
        case .workflow, .bug, .feature:
            githubDestination(for: draft)
        }
    }

    private func githubDestination(for draft: FeedbackDraft) -> FeedbackDestination {
        let url = url(
            base: Constants.issueTrackerURLString,
            queryItems: [
                URLQueryItem(name: "template", value: "feedback.yml"),
                URLQueryItem(name: "title", value: title(for: draft)),
                URLQueryItem(name: "install-method", value: draft.metadata.installMethod.rawValue),
                URLQueryItem(name: "version", value: draft.metadata.appVersion),
                URLQueryItem(name: "macos", value: draft.metadata.macOSVersion),
                URLQueryItem(name: "workflow", value: workflowValue(for: draft)),
                URLQueryItem(name: "expectation", value: trimmed(draft.expectedHelp)),
                URLQueryItem(name: "actual-result", value: trimmed(draft.actualResult)),
                URLQueryItem(name: "blockers", value: trimmed(draft.blockers)),
                URLQueryItem(name: "quote-permission", value: "No"),
                URLQueryItem(name: "quote", value: "")
            ],
            fallback: Constants.repositoryURLString
        )

        return FeedbackDestination(
            label: "GitHub",
            guidance: "Opens GitHub’s structured feedback form with your fields pre-filled for review.",
            url: url
        )
    }

    private func mailDestination(for draft: FeedbackDraft) -> FeedbackDestination {
        let url = url(
            base: "mailto:\(Constants.supportEmail)",
            queryItems: [
                URLQueryItem(name: "subject", value: title(for: draft)),
                URLQueryItem(name: "body", value: body(for: draft))
            ],
            fallback: Constants.repositoryURLString
        )

        return FeedbackDestination(
            label: "Mail",
            guidance: "Opens Mail with a draft message that you can edit before sending.",
            url: url
        )
    }

    private func title(for draft: FeedbackDraft) -> String {
        let summary = trimmed(draft.summary).isEmpty ? "OpenPaste feedback" : trimmed(draft.summary)
        return "\(draft.category.summaryPrefix) \(summary)"
    }

    private func workflowValue(for draft: FeedbackDraft) -> String {
        let categoryLine = draft.category == .workflow ? nil : "Feedback type: \(draft.category.title)"
        return [categoryLine, trimmed(draft.workflow)]
            .compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: "\n\n")
    }

    private func body(for draft: FeedbackDraft) -> String {
        var sections = [
            "- **Install method:** \(draft.metadata.installMethod.rawValue)",
            "- **OpenPaste version:** \(draft.metadata.appVersion)",
            "- **macOS version:** \(draft.metadata.macOSVersion)",
            "",
            "## \(draft.category.title)",
            "- **Short summary:** \(fallback(trimmed(draft.summary)))",
            "",
            "### \(draft.category.workflowPrompt)",
            fallback(trimmed(draft.workflow)),
            "",
            "### \(draft.category.expectationPrompt)",
            fallback(trimmed(draft.expectedHelp)),
            "",
            "### \(draft.category.actualPrompt)",
            fallback(trimmed(draft.actualResult))
        ]

        let blockers = trimmed(draft.blockers)
        if !blockers.isEmpty {
            sections.append(contentsOf: ["", "### \(draft.category.blockersPrompt)", blockers])
        }

        if draft.category == .praise, draft.publicQuoteAllowed {
            sections.append(contentsOf: [
                "",
                "- **Can we quote your positive feedback publicly?** Yes",
                "- **Optional one-line quote:** \(fallback(trimmed(draft.publicQuote)))"
            ])
        }

        return sections.joined(separator: "\n")
    }

    private func url(base: String, queryItems: [URLQueryItem], fallback: String) -> URL {
        guard var components = URLComponents(string: base) else {
            return URL(string: fallback) ?? URL(fileURLWithPath: "/")
        }

        components.queryItems = queryItems
        return components.url ?? URL(string: fallback) ?? URL(fileURLWithPath: "/")
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func fallback(_ value: String) -> String {
        value.isEmpty ? "(left blank)" : value
    }
}