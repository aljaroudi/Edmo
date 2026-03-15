import AppKit
import Foundation

struct TerminalLauncher {
    static func launch(command: String, in terminal: TerminalApp, at projectPath: String) {
        let script: String
        switch terminal {
        case .terminal:
            script = """
            tell application "Terminal"
                activate
                do script "cd \(escaped(projectPath)) && \(escaped(command))"
            end tell
            """
        case .iterm2:
            script = """
            tell application "iTerm"
                activate
                set newWindow to (create window with default profile)
                tell current session of newWindow
                    write text "cd \(escaped(projectPath)) && \(escaped(command))"
                end tell
            end tell
            """
        case .warp:
            script = """
            tell application "Warp"
                activate
            end tell
            delay 0.5
            tell application "System Events"
                keystroke "cd \(escaped(projectPath)) && \(escaped(command))"
                key code 36
            end tell
            """
        case .ghostty:
            script = """
            tell application "Ghostty"
                activate
            end tell
            delay 0.5
            tell application "System Events"
                keystroke "cd \(escaped(projectPath)) && \(escaped(command))"
                key code 36
            end tell
            """
        case .custom:
            copyToClipboard(command: "cd \(projectPath) && \(command)")
            return
        }

        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        appleScript?.executeAndReturnError(&error)

        if error != nil {
            copyToClipboard(command: "cd \(projectPath) && \(command)")
        }
    }

    private static func escaped(_ str: String) -> String {
        str.replacingOccurrences(of: "\\", with: "\\\\")
           .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static func copyToClipboard(command: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
    }
}
