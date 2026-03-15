import SwiftUI

struct CommandPaletteItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let action: () -> Void
}

struct CommandPaletteView: View {
    @Bindable var state: ProjectState
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    private var items: [CommandPaletteItem] {
        var result: [CommandPaletteItem] = []

        // Navigation
        result.append(CommandPaletteItem(title: "Go to Dashboard", icon: "square.grid.2x2") {
            state.selectedTab = .dashboard; dismiss()
        })
        result.append(CommandPaletteItem(title: "Go to Work", icon: "checklist") {
            state.selectedTab = .work; dismiss()
        })
        result.append(CommandPaletteItem(title: "Go to PRDs", icon: "doc.text") {
            state.selectedTab = .prds; dismiss()
        })
        result.append(CommandPaletteItem(title: "Go to Settings", icon: "gear") {
            state.selectedTab = .settings; dismiss()
        })

        // Actions
        result.append(CommandPaletteItem(title: "New PRD", icon: "plus.circle") {
            state.showNewPRDSheet = true; dismiss()
        })
        result.append(CommandPaletteItem(title: "Refresh All", icon: "arrow.clockwise") {
            Task { await state.refreshAll() }; dismiss()
        })

        // PRD-specific
        for prd in state.prds {
            result.append(CommandPaletteItem(title: "PRD: \(prd.title)", icon: "doc") {
                state.selectedTab = .prds; dismiss()
            })
            result.append(CommandPaletteItem(title: "Extract Tasks from \(prd.title)", icon: "list.bullet.rectangle") {
                let slug = prd.url.deletingPathExtension().lastPathComponent
                state.launchCommand(
                    action: .extractTasks,
                    context: CommandContext(
                        slug: slug,
                        prdPath: ".edmo/prd/\(prd.url.lastPathComponent)",
                        tasksPath: ".edmo/tasks/\(slug).json"
                    )
                )
                dismiss()
            })
        }

        // Issue-specific
        for issue in state.issues.prefix(20) {
            result.append(CommandPaletteItem(title: "Issue #\(issue.number): \(issue.title)", icon: "exclamationmark.circle") {
                state.selectedTab = .work; dismiss()
            })
            result.append(CommandPaletteItem(title: "Implement Issue #\(issue.number)", icon: "hammer") {
                state.launchCommand(action: .implementIssue, context: CommandContext(issueNumber: issue.number))
                dismiss()
            })
        }

        // Task-specific
        for ts in state.taskSets {
            result.append(CommandPaletteItem(title: "Tasks: \(ts.description)", icon: "checklist") {
                state.selectedTab = .work; dismiss()
            })
            if ts.stories.contains(where: { $0.issueNumber == nil }) {
                result.append(CommandPaletteItem(title: "Create All Issues for \(ts.description)", icon: "plus.circle.fill") {
                    Task { await state.createAllIssues(in: ts) }
                    dismiss()
                })
            }
            if ts.isAllDone {
                result.append(CommandPaletteItem(title: "Clean Up \(ts.description)", icon: "trash") {
                    state.cleanUpTaskSet(ts)
                    dismiss()
                })
            }
        }

        // Filter with fuzzy matching
        if searchText.isEmpty { return result }
        return result
            .compactMap { item -> (CommandPaletteItem, Int)? in
                if let score = fuzzyMatch(query: searchText, target: item.title) {
                    return (item, score)
                }
                return nil
            }
            .sorted { $0.1 < $1.1 }
            .map(\.0)
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

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search commands...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .onSubmit {
                        if let first = items.first {
                            first.action()
                        }
                    }
            }
            .padding()

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(items) { item in
                        Button {
                            item.action()
                        } label: {
                            HStack {
                                Image(systemName: item.icon)
                                    .frame(width: 20)
                                Text(item.title)
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
            .frame(maxHeight: 400)
        }
        .frame(width: 500)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary))
    }
}
