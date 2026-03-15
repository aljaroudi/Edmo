import SwiftUI

struct WorkListView: View {
    @Bindable var state: ProjectState
    @State private var searchText = ""
    @State private var filterState = "all"

    private var filteredStories: [(story: Story, taskSet: TaskSet)] {
        var result: [(Story, TaskSet)] = []
        for ts in state.taskSets {
            for story in ts.stories {
                result.append((story, ts))
            }
        }
        if filterState == "open" { result = result.filter { $0.0.status == .open } }
        else if filterState == "done" { result = result.filter { $0.0.status == .done } }
        if !searchText.isEmpty {
            result = result.filter {
                $0.0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.0.description.localizedCaseInsensitiveContains(searchText)
            }
        }
        // Open items first
        result.sort { lhs, rhs in
            if lhs.0.status != rhs.0.status { return lhs.0.status == .open }
            return lhs.0.priority < rhs.0.priority
        }
        return result
    }

    private var filteredIssues: [Issue] {
        guard state.ghAvailable else { return [] }
        var result = state.issues
        if filterState == "open" { result = result.filter(\.isOpen) }
        else if filterState == "done" { result = result.filter { !$0.isOpen } }
        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.labels.contains(where: { $0.name.localizedCaseInsensitiveContains(searchText) })
            }
        }
        return result
    }

    var body: some View {
        List {
            if !filteredStories.isEmpty {
                Section("Tasks") {
                    ForEach(filteredStories, id: \.story.id) { item in
                        WorkStoryRow(story: item.story, taskSet: item.taskSet, state: state)
                    }
                }
            }

            if !filteredIssues.isEmpty {
                Section("Issues") {
                    ForEach(filteredIssues) { issue in
                        NavigationLink(value: NavigationDestination.issueDetail(issue)) {
                            WorkIssueRow(issue: issue, state: state)
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search work items...")
        .toolbar {
            ToolbarItem {
                Picker("Filter", selection: $filterState) {
                    Text("All").tag("all")
                    Text("Open").tag("open")
                    Text("Done").tag("done")
                }
                .pickerStyle(.segmented)
            }
        }
        .navigationTitle("Work")
        .overlay {
            if filteredStories.isEmpty && filteredIssues.isEmpty && !state.isLoading {
                ContentUnavailableView {
                    Label("No Work Items", systemImage: "checklist")
                } description: {
                    Text("Extract tasks from a PRD or create GitHub issues to get started.")
                }
            }
        }
    }
}

// MARK: - Story Row with Start button

struct WorkStoryRow: View {
    let story: Story
    let taskSet: TaskSet
    @Bindable var state: ProjectState

    var body: some View {
        HStack {
            Button {
                state.toggleStoryStatus(in: taskSet, storyID: story.id)
            } label: {
                Image(systemName: story.status == .done ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(story.status == .done ? .green : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(story.title)
                        .strikethrough(story.status == .done)
                    if let num = story.issueNumber {
                        Text("#\(num)")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15), in: Capsule())
                    }
                }
                Text(story.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(taskSet.description)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if story.status == .open {
                startButton
            }
        }
        .padding(.vertical, 2)
    }

    private var startButton: some View {
        Menu {
            ForEach(state.detectedCLITools) { tool in
                Button(tool.displayName) {
                    startImplementing(with: tool)
                }
            }
        } label: {
            Label("Start", systemImage: "play.fill")
                .font(.caption)
        } primaryAction: {
            if let cli = state.selectedCLI {
                startImplementing(with: cli)
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .disabled(state.detectedCLITools.isEmpty)
    }

    private func startImplementing(with tool: CLITool) {
        state.selectedCLI = tool
        state.saveConfig()
        state.launchCommand(
            action: .implementStory,
            context: CommandContext(
                storyTitle: story.title,
                storyDescription: story.description,
                acceptanceCriteria: story.acceptanceCriteria.joined(separator: "; ")
            )
        )
    }
}

// MARK: - Issue Row with Start button

struct WorkIssueRow: View {
    let issue: Issue
    @Bindable var state: ProjectState

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: issue.isOpen ? "circle" : "checkmark.circle.fill")
                        .foregroundStyle(issue.isOpen ? .green : .purple)
                    Text("#\(issue.number)")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    Text(issue.title)
                        .lineLimit(1)
                }
                if !issue.labels.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(issue.labels, id: \.name) { label in
                            Text(label.name)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.quaternary, in: Capsule())
                        }
                    }
                }
            }

            Spacer()

            if issue.isOpen {
                Menu {
                    ForEach(state.detectedCLITools) { tool in
                        Button(tool.displayName) {
                            startImplementing(with: tool)
                        }
                    }
                } label: {
                    Label("Start", systemImage: "play.fill")
                        .font(.caption)
                } primaryAction: {
                    if let cli = state.selectedCLI {
                        startImplementing(with: cli)
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .disabled(state.detectedCLITools.isEmpty)
            }
        }
        .padding(.vertical, 2)
    }

    private func startImplementing(with tool: CLITool) {
        state.selectedCLI = tool
        state.saveConfig()
        state.launchCommand(
            action: .implementIssue,
            context: CommandContext(issueNumber: issue.number)
        )
    }
}
