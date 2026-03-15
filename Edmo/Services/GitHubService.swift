import Foundation

struct GitHubService {
    static func fetchIssues(at projectPath: String) async throws -> [Issue] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", "cd \(shellEscape(projectPath)) && gh issue list --json number,title,body,labels,assignees,state --limit 100"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        try process.run()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw GitHubError.ghFailed
        }

        let decoder = JSONDecoder()
        return try decoder.decode([Issue].self, from: data)
    }

    static func createIssue(title: String, body: String, at projectPath: String) async throws -> Int {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", "cd \(shellEscape(projectPath)) && gh issue create --title \(shellEscape(title)) --body \(shellEscape(body))"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        try process.run()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw GitHubError.ghFailed
        }

        let output = String(data: data, encoding: .utf8) ?? ""
        // gh issue create outputs URL like https://github.com/owner/repo/issues/123
        if let lastComponent = output.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "/").last,
           let number = Int(lastComponent) {
            return number
        }
        throw GitHubError.parseError
    }

    private static func shellEscape(_ arg: String) -> String {
        "'" + arg.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    enum GitHubError: LocalizedError {
        case ghFailed
        case parseError
        case notInstalled

        var errorDescription: String? {
            switch self {
            case .ghFailed: "GitHub CLI command failed. Ensure 'gh' is installed and authenticated."
            case .parseError: "Failed to parse GitHub CLI output."
            case .notInstalled: "GitHub CLI (gh) is not installed. Install it from https://cli.github.com"
            }
        }
    }
}
