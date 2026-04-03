import Foundation

struct FeedbackDestination: Equatable, Sendable {
    let label: String
    let guidance: String
    let url: URL
}

protocol FeedbackRouterProtocol: Sendable {
    func destination(for draft: FeedbackDraft) -> FeedbackDestination
}