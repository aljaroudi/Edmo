import SwiftUI

struct CommandPaletteItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String?
    let icon: String
    let searchText: String
    let action: @MainActor () -> Void

    init(
        title: String,
        subtitle: String? = nil,
        icon: String,
        searchText: String? = nil,
        action: @escaping @MainActor () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.searchText = searchText ?? title
        self.action = action
    }
}

struct CommandPaletteView: View {
    @Bindable var state: ProjectState
    let mode: CommandPaletteMode
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    @Environment(\.dismiss) private var dismiss

    private var items: [CommandPaletteItem] {
        let result: [CommandPaletteItem] = switch mode {
        case .commands:
            commandItems
        case .projects:
            projectItems
        }

        if searchText.isEmpty { return result }
        return result
            .compactMap { item -> (CommandPaletteItem, Int)? in
                if let score = fuzzyMatch(query: searchText, target: item.searchText) {
                    return (item, score)
                }
                return nil
            }
            .sorted { $0.1 < $1.1 }
            .map(\.0)
    }

    private var commandItems: [CommandPaletteItem] {
        var result: [CommandPaletteItem] = []

        result.append(CommandPaletteItem(title: "Go to Dashboard", icon: "square.grid.2x2") {
            perform { state.selectedTab = .dashboard }
        })
        result.append(CommandPaletteItem(title: "Go to Work", icon: "checklist") {
            perform { state.selectedTab = .work }
        })
        result.append(CommandPaletteItem(title: "Go to PRDs", icon: "doc.text") {
            perform { state.selectedTab = .prds }
        })
        result.append(CommandPaletteItem(title: "Go to Settings", icon: "gear") {
            perform { state.selectedTab = .settings }
        })

        result.append(CommandPaletteItem(title: "New PRD", icon: "plus.circle") {
            perform { state.showNewPRDSheet = true }
        })
        result.append(CommandPaletteItem(title: "Refresh All", icon: "arrow.clockwise") {
            perform {
                Task { await state.refreshAll() }
            }
        })

        for prd in state.prds {
            result.append(CommandPaletteItem(title: "PRD: \(prd.title)", icon: "doc") {
                perform { state.selectedTab = .prds }
            })
            result.append(CommandPaletteItem(
                title: "Extract Tasks from \(prd.title)",
                icon: "list.bullet.rectangle"
            ) {
                let slug = prd.url.deletingPathExtension().lastPathComponent
                perform {
                    state.launchCommand(
                        action: .extractTasks,
                        context: CommandContext(
                            slug: slug,
                            prdPath: ".edmo/prd/\(prd.url.lastPathComponent)",
                            tasksPath: ".edmo/tasks/\(slug).json"
                        )
                    )
                }
            })
        }

        for issue in state.issues.prefix(20) {
            result.append(CommandPaletteItem(
                title: "Issue #\(issue.number): \(issue.title)",
                icon: "exclamationmark.circle"
            ) {
                perform { state.selectedTab = .work }
            })
            result.append(CommandPaletteItem(title: "Implement Issue #\(issue.number)", icon: "hammer") {
                perform {
                    state.launchCommand(action: .implementIssue, context: CommandContext(issueNumber: issue.number))
                }
            })
        }

        for ts in state.taskSets {
            result.append(CommandPaletteItem(title: "Tasks: \(ts.description)", icon: "checklist") {
                perform { state.selectedTab = .work }
            })
            if ts.stories.contains(where: { $0.issueNumber == nil }) {
                result.append(CommandPaletteItem(
                    title: "Create All Issues for \(ts.description)",
                    icon: "plus.circle.fill"
                ) {
                    perform {
                        Task { await state.createAllIssues(in: ts) }
                    }
                })
            }
            if ts.isAllDone {
                result.append(CommandPaletteItem(title: "Clean Up \(ts.description)", icon: "trash") {
                    perform { state.cleanUpTaskSet(ts) }
                })
            }
        }

        return result
    }

    private var projectItems: [CommandPaletteItem] {
        var result = state.projects.map { project in
            let isCurrent = project.id == state.currentProject?.id
            let subtitle = isCurrent ? "\(project.path) • Current project" : project.path

            return CommandPaletteItem(
                title: project.displayName,
                subtitle: subtitle,
                icon: isCurrent ? "folder.fill" : "folder",
                searchText: "\(project.displayName) \(project.path)"
            ) {
                perform { state.openProject(path: project.path) }
            }
        }

        result.append(CommandPaletteItem(
            title: "Add Project",
            subtitle: "Open a new project folder",
            icon: "plus.circle",
            searchText: "Add Project Open Folder New Project"
        ) {
            perform { state.promptForProject() }
        })

        return result
    }

    /// Returns a score if all characters in query appear in order in target (lower = better). Nil if no match.
    private func fuzzyMatch(query: String, target: String) -> Int? {
        let query = query.lowercased()
        let target = target.lowercased()
        var score = 0
        var targetIndex = target.startIndex
        for char in query {
            guard let found = target[targetIndex...].firstIndex(of: char) else { return nil }
            score += target.distance(from: targetIndex, to: found)
            targetIndex = target.index(after: found)
        }
        return score
    }

    private func perform(_ action: @escaping @MainActor () -> Void) {
        dismiss()
        Task { @MainActor in
            action()
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(mode.placeholder, text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($isSearchFocused)
                    .onSubmit {
                        if let first = items.first {
                            first.action()
                        }
                    }
            }
            .padding()

            Divider()

            ScrollView {
                if items.isEmpty {
                    ContentUnavailableView(
                        mode.emptyStateMessage,
                        systemImage: mode == .projects ? "folder.badge.questionmark" : "magnifyingglass"
                    )
                    .frame(maxWidth: .infinity, minHeight: 180)
                } else {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(items) { item in
                            Button {
                                item.action()
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: item.icon)
                                        .frame(width: 20)
                                        .padding(.top, item.subtitle == nil ? 0 : 2)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.title)
                                        if let subtitle = item.subtitle {
                                            Text(subtitle)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .frame(maxHeight: 400)
        }
        .frame(width: 500)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary))
        .onAppear {
            isSearchFocused = true
        }
    }
}
