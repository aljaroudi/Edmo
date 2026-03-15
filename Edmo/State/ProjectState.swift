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
    var showCommandPalette: Bool = false
    var showNewPRDSheet: Bool = false
    var showShortcutHelp: Bool = false
    var selectedStoryID: String?

    private var fileWatcher: FileWatcher?

    var hasProject: Bool { projectPath != nil }

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

    func openProject(path: String) {
        // Upsert into project list
        if let idx = projects.firstIndex(where: { $0.path == path }) {
            currentProject = projects[idx]
        } else {
            let info = ProjectInfo(path: path)
            projects.append(info)
            currentProject = info
            saveProjects()
        }

        projectPath = path
        selectedDestination = .dashboard
        loadConfig()
        startWatching()
        Task {
            await detectTools()
            await refreshAll()
        }
    }

    func removeProject(id: UUID) {
        projects.removeAll { $0.id == id }
        saveProjects()
        if currentProject?.id == id {
            currentProject = nil
            projectPath = nil
            stopWatching()
            issues = []
            prds = []
            taskSets = []
        }
    }

    func detectTools() async {
        let tools = await CLIDetector.detectTools()
        let gh = await CLIDetector.isGHAvailable()
        detectedCLITools = tools
        ghAvailable = gh
        if selectedCLI == nil {
            selectedCLI = detectedCLITools.first
        }
    }

    func loadConfig() {
        guard let path = projectPath else { return }
        if let config = EdmoConfigService.load(from: path) {
            if let cli = config.defaultCLI { selectedCLI = cli }
            if let term = config.terminalApp { selectedTerminal = term }
        }
    }

    func saveConfig() {
        guard let path = projectPath else { return }
        let config = EdmoConfig(defaultCLI: selectedCLI, terminalApp: selectedTerminal)
        try? EdmoConfigService.save(config, to: path)
    }

    func refreshAll() async {
        refreshPRDs()
        refreshTasks()
        await refreshIssues()
    }

    func refreshIssues() async {
        guard let path = projectPath, ghAvailable else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            issues = try await GitHubService.fetchIssues(at: path)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshPRDs() {
        guard let path = projectPath else { return }
        let prdDir = URL(fileURLWithPath: path).appendingPathComponent(".edmo/prd")
        guard FileManager.default.fileExists(atPath: prdDir.path) else {
            prds = []
            return
        }
        do {
            let files = try FileManager.default.contentsOfDirectory(at: prdDir, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "md" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
            prds = files.compactMap { url -> PRDFile? in
                do {
                    return try PRDFile(url: url)
                } catch {
                    print("[ProjectState] Failed to load PRD \(url.lastPathComponent): \(error)")
                    return nil
                }
            }
        } catch {
            prds = []
        }
    }

    func refreshTasks() {
        guard let path = projectPath else { return }
        let edmoDir = URL(fileURLWithPath: path).appendingPathComponent(".edmo")
        taskSets = TaskFileService.scanTaskSets(at: edmoDir)
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
}
