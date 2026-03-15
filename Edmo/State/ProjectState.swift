import AppKit
import Foundation
import Observation

enum NavigationDestination: Hashable {
    case dashboard
    case work
    case issueDetail(Issue)
    case prds
    case prdPreview(PRDFile)
    case settings
}

enum ProjectTab: String, CaseIterable, Hashable {
    case dashboard = "Dashboard"
    case work = "Work"
    case prds = "PRDs"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .dashboard: "square.grid.2x2"
        case .work: "checklist"
        case .prds: "doc.text"
        case .settings: "gear"
        }
    }
}

enum CommandPaletteMode {
    case commands
    case projects

    var placeholder: String {
        switch self {
        case .commands:
            "Search commands..."
        case .projects:
            "Search projects..."
        }
    }

    var emptyStateMessage: String {
        switch self {
        case .commands:
            "No matching commands"
        case .projects:
            "No matching projects"
        }
    }
}

private struct ToolDetectionResult {
    let tools: [CLITool]
    let ghAvailable: Bool
}

@Observable
final class ProjectState {
    private static let projectsKey = "edmo.recentProjects"

    var projects: [ProjectInfo] = []
    var currentProject: ProjectInfo?
    var projectPath: String?
    var issues: [Issue] = []
    var prds: [PRDFile] = []
    var taskSets: [TaskSet] = []
    var detectedCLITools: [CLITool] = []
    var selectedCLI: CLITool?
    var selectedTerminal: TerminalApp = .terminal
    var ghAvailable: Bool = false

    var selectedDestination: NavigationDestination? = .dashboard
    var selectedTab: ProjectTab = .dashboard
    var isLoading: Bool = false
    var errorMessage: String?
    var commandPaletteMode: CommandPaletteMode = .commands
    var showCommandPalette: Bool = false
    var showNewPRDSheet: Bool = false
    var showShortcutHelp: Bool = false
    var selectedStoryID: String?
    var projectTransitionName: String?

    private var fileWatcher: FileWatcher?
    private var activeProjectTransitionID: UUID?
    private var projectLoadTask: Task<Void, Never>?

    var hasProject: Bool { projectPath != nil }
    var isProjectSwitching: Bool { projectTransitionName != nil }

    init() {
        loadProjects()
    }

    // MARK: - Multi-project persistence

    func loadProjects() {
        guard let data = UserDefaults.standard.data(forKey: Self.projectsKey),
              let decoded = try? JSONDecoder().decode([ProjectInfo].self, from: data) else { return }
        projects = decoded
    }

    func saveProjects() {
        guard let data = try? JSONEncoder().encode(projects) else { return }
        UserDefaults.standard.set(data, forKey: Self.projectsKey)
    }

    func openCommandPalette(mode: CommandPaletteMode) {
        commandPaletteMode = mode
        showCommandPalette = true
    }

    func promptForProject() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose a project folder"
        if panel.runModal() == .OK, let url = panel.url {
            openProject(path: url.path)
        }
    }

    func openProject(path: String) {
        startProjectSwitch(to: upsertProject(path: path))
    }

    func removeProject(id: UUID) {
        projects.removeAll { $0.id == id }
        saveProjects()
        if currentProject?.id == id {
            projectLoadTask?.cancel()
            projectLoadTask = nil
            activeProjectTransitionID = nil
            projectTransitionName = nil
            currentProject = nil
            projectPath = nil
            stopWatching()
            issues = []
            prds = []
            taskSets = []
        }
    }

    func detectTools() async {
        let toolDetection = await Self.detectToolState()
        detectedCLITools = toolDetection.tools
        ghAvailable = toolDetection.ghAvailable
        if selectedCLI == nil {
            selectedCLI = detectedCLITools.first
        }
    }

    func saveConfig() {
        guard let path = projectPath else { return }
        let config = EdmoConfig(defaultCLI: selectedCLI, terminalApp: selectedTerminal)
        try? EdmoConfigService.save(config, to: path)
    }

    func refreshAll() async {
        guard !isProjectSwitching else { return }
        refreshPRDs()
        refreshTasks()
        await refreshIssues()
    }

    func refreshIssues() async {
        guard !isProjectSwitching else { return }
        guard let path = projectPath else {
            issues = []
            return
        }
        guard ghAvailable else {
            issues = []
            return
        }

        isLoading = true
        defer {
            if projectPath == path {
                isLoading = false
            }
        }

        do {
            let fetchedIssues = try await GitHubService.fetchIssues(at: path)
            guard projectPath == path, !isProjectSwitching else { return }
            issues = fetchedIssues
            errorMessage = nil
        } catch {
            guard projectPath == path, !isProjectSwitching else { return }
            errorMessage = error.localizedDescription
        }
    }

    func refreshPRDs() {
        guard let path = projectPath else {
            prds = []
            return
        }
        prds = Self.loadPRDs(at: path)
    }

    func refreshTasks() {
        guard let path = projectPath else {
            taskSets = []
            return
        }
        taskSets = Self.loadTaskSets(at: path)
    }

    func startWatching() {
        fileWatcher?.stop()
        guard let path = projectPath else { return }
        let edmoDir = path + "/.edmo"

        // Only watch if .edmo exists — don't create it eagerly
        guard FileManager.default.fileExists(atPath: edmoDir) else { return }

        fileWatcher = FileWatcher(path: edmoDir) { [weak self] in
            Task { @MainActor in
                self?.refreshPRDs()
                self?.refreshTasks()
            }
        }
        fileWatcher?.start()
    }

    func stopWatching() {
        fileWatcher?.stop()
        fileWatcher = nil
    }

    func launchCommand(action: CommandAction, context: CommandContext) {
        guard let cli = selectedCLI, let path = projectPath else { return }
        let command = CommandBuilder.build(action: action, tool: cli, context: context)
        TerminalLauncher.launch(command: command, in: selectedTerminal, at: path)
    }

    func toggleStoryStatus(in taskSet: TaskSet, storyID: String) {
        guard let path = projectPath else { return }
        guard var ts = taskSets.first(where: { $0.id == taskSet.id }),
              let idx = ts.stories.firstIndex(where: { $0.id == storyID }) else { return }

        ts.stories[idx].status = ts.stories[idx].status == .open ? .done : .open
        ts.updatedAt = Date()

        let url = URL(fileURLWithPath: path)
            .appendingPathComponent(".edmo/tasks/\(ts.slug).json")
        try? TaskFileService.save(ts, to: url)
        refreshTasks()
    }

    func createIssueForStory(in taskSet: TaskSet, storyID: String) async {
        guard let path = projectPath else { return }
        guard var ts = taskSets.first(where: { $0.id == taskSet.id }),
              let idx = ts.stories.firstIndex(where: { $0.id == storyID }) else { return }

        let story = ts.stories[idx]
        let body = """
        \(story.description)

        ## Acceptance Criteria
        \(story.acceptanceCriteria.map { "- [ ] \($0)" }.joined(separator: "\n"))
        """

        do {
            let number = try await GitHubService.createIssue(title: story.title, body: body, at: path)
            ts.stories[idx].issueNumber = number
            ts.updatedAt = Date()

            let url = URL(fileURLWithPath: path)
                .appendingPathComponent(".edmo/tasks/\(ts.slug).json")
            try TaskFileService.save(ts, to: url)
            refreshTasks()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createAllIssues(in taskSet: TaskSet) async {
        guard let ts = taskSets.first(where: { $0.id == taskSet.id }) else { return }
        for story in ts.stories where story.issueNumber == nil {
            await createIssueForStory(in: ts, storyID: story.id)
        }
    }

    func taskSet(for prd: PRDFile) -> TaskSet? {
        let slug = prd.url.deletingPathExtension().lastPathComponent
        return taskSets.first(where: { $0.slug == slug })
    }

    func savePRD(content: String, to url: URL) {
        try? content.write(to: url, atomically: true, encoding: .utf8)
        refreshPRDs()
    }

    func cleanUpTaskSet(_ taskSet: TaskSet) {
        guard let path = projectPath else { return }
        let url = URL(fileURLWithPath: path)
            .appendingPathComponent(".edmo/tasks/\(taskSet.slug).json")
        try? FileManager.default.removeItem(at: url)
        refreshTasks()
    }

    private func upsertProject(path: String) -> ProjectInfo {
        if let idx = projects.firstIndex(where: { $0.path == path }) {
            return projects[idx]
        }

        let info = ProjectInfo(path: path)
        projects.append(info)
        saveProjects()
        return info
    }

    private func startProjectSwitch(to project: ProjectInfo) {
        projectLoadTask?.cancel()

        let requestID = UUID()
        activeProjectTransitionID = requestID
        projectTransitionName = project.displayName
        currentProject = project
        projectPath = project.path
        selectedDestination = .dashboard
        errorMessage = nil
        issues = []
        prds = []
        taskSets = []
        detectedCLITools = []
        ghAvailable = false
        selectedCLI = nil
        selectedTerminal = .terminal
        stopWatching()

        let projectPath = project.path
        projectLoadTask = Task { [weak self] in
            guard let self else { return }

            let config = EdmoConfigService.load(from: projectPath)
            let toolDetection = await Self.detectToolState()
            let loadedPRDs = Self.loadPRDs(at: projectPath)
            let loadedTaskSets = Self.loadTaskSets(at: projectPath)

            var loadedIssues: [Issue] = []
            var issueError: String?
            if toolDetection.ghAvailable {
                do {
                    loadedIssues = try await GitHubService.fetchIssues(at: projectPath)
                } catch {
                    issueError = error.localizedDescription
                }
            }

            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard self.activeProjectTransitionID == requestID else { return }

                self.detectedCLITools = toolDetection.tools
                self.ghAvailable = toolDetection.ghAvailable
                self.selectedCLI = config?.defaultCLI ?? toolDetection.tools.first
                self.selectedTerminal = config?.terminalApp ?? .terminal
                self.prds = loadedPRDs
                self.taskSets = loadedTaskSets
                self.issues = loadedIssues
                self.errorMessage = issueError
                self.startWatching()
                self.projectLoadTask = nil
                self.activeProjectTransitionID = nil
                self.projectTransitionName = nil
            }
        }
    }

    private static func detectToolState() async -> ToolDetectionResult {
        async let tools = CLIDetector.detectTools()
        async let ghAvailable = CLIDetector.isGHAvailable()
        return await ToolDetectionResult(tools: tools, ghAvailable: ghAvailable)
    }

    private static func loadPRDs(at path: String) -> [PRDFile] {
        let prdDir = URL(fileURLWithPath: path).appendingPathComponent(".edmo/prd")
        guard FileManager.default.fileExists(atPath: prdDir.path) else { return [] }

        do {
            let files = try FileManager.default.contentsOfDirectory(at: prdDir, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "md" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }

            return files.compactMap { url -> PRDFile? in
                do {
                    return try PRDFile(url: url)
                } catch {
                    print("[ProjectState] Failed to load PRD \(url.lastPathComponent): \(error)")
                    return nil
                }
            }
        } catch {
            return []
        }
    }

    private static func loadTaskSets(at path: String) -> [TaskSet] {
        let edmoDir = URL(fileURLWithPath: path).appendingPathComponent(".edmo")
        return TaskFileService.scanTaskSets(at: edmoDir)
    }
}
