import Foundation

enum CLITool: String, Codable, CaseIterable, Identifiable {
    case claude
    case codex

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claude: "Claude"
        case .codex: "Codex"
        }
    }
}

enum TerminalApp: String, Codable, CaseIterable, Identifiable {
    case terminal = "Terminal"
    case iterm2 = "iTerm2"
    case warp = "Warp"
    case ghostty = "Ghostty"
    case custom = "Custom"

    var id: String { rawValue }
}

struct EdmoConfig: Codable {
    var defaultCLI: CLITool?
    var terminalApp: TerminalApp?
    var customTerminalBundleID: String?
}
