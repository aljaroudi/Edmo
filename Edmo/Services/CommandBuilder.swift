import Foundation

struct CommandContext {
    var slug: String?
    var ideaText: String?
    var issueNumber: Int?
    var prdPath: String?
    var tasksPath: String?
    var projectPath: String?
    var storyTitle: String?
    var storyDescription: String?
    var acceptanceCriteria: String?
}

enum CommandAction {
    case createPRD
    case extractTasks
    case implementIssue
    case implementStory
}

struct CommandBuilder {
    static func build(action: CommandAction, tool: CLITool, context: CommandContext) -> String {
        let templates = Self.templates(for: tool)
        let template = templates[action] ?? ""
        return fillPlaceholders(template, context: context)
    }

    private static func templates(for tool: CLITool) -> [CommandAction: String] {
        switch tool {
        case .claude:
            return [
                .createPRD: "claude \"Create a PRD for: {idea_text}. Save it as a markdown file at .edmo/prd/{slug}.md\"",
                .extractTasks: "claude \"Read the PRD at {prd_path} and extract user stories into a JSON task file. Save the output to {tasks_path}. Use this JSON schema: {{\\\"slug\\\": string, \\\"prdFile\\\": string, \\\"branchName\\\": string, \\\"description\\\": string, \\\"createdAt\\\": ISO8601, \\\"updatedAt\\\": ISO8601, \\\"stories\\\": [{{\\\"id\\\": string, \\\"title\\\": string, \\\"description\\\": string, \\\"acceptanceCriteria\\\": [string], \\\"priority\\\": int, \\\"status\\\": \\\"open\\\", \\\"issueNumber\\\": null, \\\"notes\\\": \\\"\\\"}}]}}\"",
                .implementIssue: "claude \"Implement GitHub issue #{issue_number} in this repository. Read the issue details and write the code needed to satisfy the requirements.\"",
                .implementStory: "claude \"Implement: {story_title}. {story_description}. Acceptance criteria: {acceptance_criteria}\""
            ]
        case .codex:
            return [
                .createPRD: "codex \"Create a PRD for: {idea_text}. Save it as a markdown file at .edmo/prd/{slug}.md\"",
                .extractTasks: "codex \"Read the PRD at {prd_path} and extract user stories into a JSON task file. Save the output to {tasks_path}. Use this JSON schema: {{\\\"slug\\\": string, \\\"prdFile\\\": string, \\\"branchName\\\": string, \\\"description\\\": string, \\\"createdAt\\\": ISO8601, \\\"updatedAt\\\": ISO8601, \\\"stories\\\": [{{\\\"id\\\": string, \\\"title\\\": string, \\\"description\\\": string, \\\"acceptanceCriteria\\\": [string], \\\"priority\\\": int, \\\"status\\\": \\\"open\\\", \\\"issueNumber\\\": null, \\\"notes\\\": \\\"\\\"}}]}}\"",
                .implementIssue: "codex \"Implement GitHub issue #{issue_number} in this repository.\"",
                .implementStory: "codex \"Implement: {story_title}. {story_description}. Acceptance criteria: {acceptance_criteria}\""
            ]
        }
    }

    private static func fillPlaceholders(_ template: String, context: CommandContext) -> String {
        var result = template
        if let slug = context.slug { result = result.replacingOccurrences(of: "{slug}", with: slug) }
        if let idea = context.ideaText { result = result.replacingOccurrences(of: "{idea_text}", with: idea) }
        if let num = context.issueNumber { result = result.replacingOccurrences(of: "{issue_number}", with: "\(num)") }
        if let prd = context.prdPath { result = result.replacingOccurrences(of: "{prd_path}", with: prd) }
        if let tasks = context.tasksPath { result = result.replacingOccurrences(of: "{tasks_path}", with: tasks) }
        if let title = context.storyTitle { result = result.replacingOccurrences(of: "{story_title}", with: title) }
        if let desc = context.storyDescription { result = result.replacingOccurrences(of: "{story_description}", with: desc) }
        if let ac = context.acceptanceCriteria { result = result.replacingOccurrences(of: "{acceptance_criteria}", with: ac) }
        return result
    }

    static func slugify(_ text: String) -> String {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .prefix(5)
            .joined(separator: "-")
    }
}
