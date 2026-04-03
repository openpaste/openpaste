import Foundation

enum FeedbackCategory: String, CaseIterable, Identifiable, Sendable {
    case workflow
    case bug
    case feature
    case praise

    var id: String { rawValue }

    var title: String {
        switch self {
        case .workflow: "Workflow Feedback"
        case .bug: "Bug Report"
        case .feature: "Feature Request"
        case .praise: "Praise / Other"
        }
    }

    var summaryPrefix: String {
        switch self {
        case .workflow: "[Feedback]"
        case .bug: "[Bug]"
        case .feature: "[Feature]"
        case .praise: "[Praise]"
        }
    }

    var destinationName: String {
        switch self {
        case .praise: "Mail"
        case .workflow, .bug, .feature: "GitHub"
        }
    }

    var summaryPlaceholder: String {
        switch self {
        case .workflow: "Search felt fast, but I couldn’t trust the result order"
        case .bug: "Pasting from the panel sends stale clipboard content"
        case .feature: "I want pinned snippets that stay separate from history"
        case .praise: "OpenPaste finally feels built for developer workflows"
        }
    }

    var workflowPrompt: String {
        switch self {
        case .workflow: "What were you trying to do?"
        case .bug: "Steps or workflow that led to the bug"
        case .feature: "What are you trying to do today?"
        case .praise: "What were you doing when OpenPaste helped?"
        }
    }

    var expectationPrompt: String {
        switch self {
        case .feature: "What feature do you wish existed?"
        case .praise: "What felt great?"
        case .workflow, .bug: "What did you expect OpenPaste to help with?"
        }
    }

    var actualPrompt: String {
        switch self {
        case .feature: "How are you working around it today?"
        case .praise: "Anything else we should know?"
        case .workflow, .bug: "What actually happened?"
        }
    }

    var blockersPrompt: String {
        switch self {
        case .praise: "Anything still confusing, slow, or untrustworthy?"
        case .workflow, .bug, .feature: "What felt confusing, slow, or untrustworthy?"
        }
    }
}