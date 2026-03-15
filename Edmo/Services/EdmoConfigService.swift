import Foundation

struct EdmoConfigService {
    static func load(from projectPath: String) -> EdmoConfig? {
        let url = URL(fileURLWithPath: projectPath).appendingPathComponent(".edmo/config.json")
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(EdmoConfig.self, from: data)
    }

    static func save(_ config: EdmoConfig, to projectPath: String) throws {
        let edmoDir = URL(fileURLWithPath: projectPath).appendingPathComponent(".edmo")
        try FileManager.default.createDirectory(at: edmoDir, withIntermediateDirectories: true)

        let url = edmoDir.appendingPathComponent("config.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: url, options: .atomic)
    }
}
