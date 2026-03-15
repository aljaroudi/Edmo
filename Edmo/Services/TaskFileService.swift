import Foundation

struct TaskFileService {
    static func load(from url: URL) throws -> TaskSet {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var taskSet = try decoder.decode(TaskSet.self, from: data)
        // Derive slug from filename if missing (Ralph format doesn't include it)
        if taskSet.slug.isEmpty {
            taskSet.slug = url.deletingPathExtension().lastPathComponent
        }
        return taskSet
    }

    static func save(_ taskSet: TaskSet, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(taskSet)
        try data.write(to: url, options: .atomic)
    }

    static func validate(_ data: Data) -> Result<TaskSet, Error> {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let taskSet = try decoder.decode(TaskSet.self, from: data)
            return .success(taskSet)
        } catch {
            return .failure(error)
        }
    }

    static func scanTaskSets(at edmoDir: URL) -> [TaskSet] {
        let tasksDir = edmoDir.appendingPathComponent("tasks")
        guard FileManager.default.fileExists(atPath: tasksDir.path) else { return [] }

        do {
            let files = try FileManager.default.contentsOfDirectory(at: tasksDir, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "json" }

            return files.compactMap { url -> TaskSet? in
                do {
                    return try load(from: url)
                } catch {
                    print("[TaskFileService] Failed to load \(url.lastPathComponent): \(error)")
                    return nil
                }
            }
        } catch {
            return []
        }
    }
}
