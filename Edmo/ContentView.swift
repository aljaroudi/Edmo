import SwiftUI

struct ContentView: View {
    @State private var state = ProjectState()

    var body: some View {
        NavigationSplitView {
            SidebarView(state: state)
        } detail: {
            projectDetailView
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $state.showNewPRDSheet) {
            NewPRDSheet(state: state)
        }
        .sheet(isPresented: $state.showShortcutHelp) {
            ShortcutCheatSheet()
        }
        .sheet(isPresented: $state.showCommandPalette) {
            CommandPaletteView(state: state)
        }
        .task {
            await state.detectTools()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await state.refreshAll() }
        }
        .frame(minWidth: 800, minHeight: 500)
        .toolbar {
            ToolbarItem {
                Button {
                    Task { await state.refreshAll() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r")
            }
        }
        // Global keyboard shortcuts
        .background {
            Group {
                Button("") { state.selectedTab = .dashboard }
                    .keyboardShortcut("1")
                Button("") { state.selectedTab = .work }
                    .keyboardShortcut("2")
                Button("") { state.selectedTab = .prds }
                    .keyboardShortcut("3")
                Button("") { state.selectedTab = .settings }
                    .keyboardShortcut(",")
                Button("") { state.showCommandPalette.toggle() }
                    .keyboardShortcut("k")
                Button("") { state.showNewPRDSheet = true }
                    .keyboardShortcut("n")
                Button("") { state.showShortcutHelp = true }
                    .keyboardShortcut("/")
                Button("") { toggleSelectedStory() }
                    .keyboardShortcut("d")
            }
            .hidden()
        }
        .overlay {
            if state.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding()
            }
        }
        .overlay(alignment: .bottom) {
            if let error = state.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                    Text(error)
                    Spacer()
                    Button("Dismiss") { state.errorMessage = nil }
                }
                .padding()
                .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                .padding()
            }
        }
    }

    @ViewBuilder
    private var projectDetailView: some View {
        if state.hasProject {
            VStack(spacing: 0) {
                // Tab bar
                Picker("Tab", selection: $state.selectedTab) {
                    ForEach(ProjectTab.allCases, id: \.self) { tab in
                        if tab == .settings {
                            Image(systemName: tab.icon)
                                .tag(tab)
                        } else {
                            Label(tab.rawValue, systemImage: tab.icon)
                                .tag(tab)
                        }
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()

                // Tab content
                tabContent
            }
        } else {
            ContentUnavailableView(
                "Select or Add a Project",
                systemImage: "folder.badge.questionmark",
                description: Text("Choose a project from the sidebar or add a new one to get started.")
            )
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch state.selectedTab {
        case .dashboard:
            DashboardView(state: state)
        case .work:
            NavigationStack {
                WorkListView(state: state)
                    .navigationDestination(for: NavigationDestination.self) { dest in
                        if case .issueDetail(let issue) = dest {
                            IssueDetailView(issue: issue, state: state)
                        }
                    }
            }
        case .prds:
            NavigationStack {
                PRDListView(state: state)
                    .navigationDestination(for: NavigationDestination.self) { dest in
                        if case .prdPreview(let prd) = dest {
                            PRDPreviewView(prd: prd, state: state)
                        }
                    }
            }
        case .settings:
            SettingsView(state: state)
        }
    }

    private func toggleSelectedStory() {
        guard let storyID = state.selectedStoryID else { return }
        if state.selectedTab == .work {
            for ts in state.taskSets {
                if ts.stories.contains(where: { $0.id == storyID }) {
                    state.toggleStoryStatus(in: ts, storyID: storyID)
                    return
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
