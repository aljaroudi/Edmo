import Foundation

struct CLIDetector {
    static func detectTools() async -> [CLITool] {
        var detected: [CLITool] = []
        for tool in CLITool.allCases {
            if await isAvailable(tool.rawValue) {
                detected.append(tool)
            }
        }
        return detected
    }

    private static func isAvailable(_ command: String) async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let home = NSHomeDirectory()
                let expandedPath = [
                    "/usr/local/bin",
                    "/opt/homebrew/bin",
                    "/opt/homebrew/sbin",
                    "\(home)/.npm-global/bin",
                    "\(home)/.local/bin",
                    "\(home)/.cargo/bin",
                    "/usr/bin",
                    "/bin",
                ].joined(separator: ":")

                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                process.arguments = ["which", command]
                process.environment = ["PATH": expandedPath, "HOME": home]
                process.standardOutput = FileHandle.nullDevice
                process.standardError = FileHandle.nullDevice
                do {
                    try process.run()
                    process.waitUntilExit()
                    continuation.resume(returning: process.terminationStatus == 0)
                } catch {
                    continuation.resume(returning: false)
                }
            }
        }
    }

    static func isGHAvailable() async -> Bool {
        await isAvailable("gh")
    }
}
