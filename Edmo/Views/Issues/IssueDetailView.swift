import SwiftUI

struct IssueDetailView: View {
    let issue: Issue
    @Bindable var state: ProjectState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                Divider()
                markdownBody
            }
            .padding()
        }
        .navigationTitle("#\(issue.number) \(issue.title)")
        .toolbar {
            ToolbarItem {
                Button("Implement") {
                    implementIssue()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(state.selectedCLI == nil)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: issue.isOpen ? "circle" : "checkmark.circle.fill")
                    .foregroundStyle(issue.isOpen ? .green : .purple)
                Text(issue.isOpen ? "Open" : "Closed")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(issue.isOpen ? Color.green.opacity(0.15) : Color.purple.opacity(0.15), in: Capsule())

                Spacer()
            }

            if !issue.labels.isEmpty {
                HStack(spacing: 4) {
                    ForEach(issue.labels, id: \.name) { label in
                        Text(label.name)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.quaternary, in: Capsule())
                    }
                }
            }

            if !issue.assignees.isEmpty {
                HStack {
                    Text("Assignees:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(issue.assignees, id: \.login) { a in
                        Text(a.login)
                            .font(.caption)
                    }
                }
            }
        }
    }

    private var markdownBody: some View {
        Text(LocalizedStringKey(issue.body))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func implementIssue() {
        state.launchCommand(
            action: .implementIssue,
            context: CommandContext(issueNumber: issue.number)
        )
    }
}
