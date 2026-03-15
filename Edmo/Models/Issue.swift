import Foundation

struct Issue: Identifiable, Codable, Hashable {
    var number: Int
    var title: String
    var body: String
    var labels: [IssueLabel]
    var assignees: [IssueAssignee]
    var state: String

    var id: Int { number }

    var isOpen: Bool { state.lowercased() == "open" }
}

struct IssueLabel: Codable, Hashable {
    var name: String
}

struct IssueAssignee: Codable, Hashable {
    var login: String
}
