import Foundation

struct PRDFile: Identifiable, Hashable {
    var id: String { url.lastPathComponent }
    var url: URL
    var title: String
    var preview: String
    var content: String

    init(url: URL) throws {
        self.url = url
        self.content = try String(contentsOf: url, encoding: .utf8)

        let lines = content.components(separatedBy: .newlines)
        let titleLine = lines.first(where: { $0.hasPrefix("# ") })
        self.title = titleLine.map { String($0.dropFirst(2)) }
            ?? url.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "-", with: " ").capitalized

        self.preview = lines
            .drop(while: { $0.trimmingCharacters(in: .whitespaces).isEmpty || $0.hasPrefix("#") })
            .prefix(3)
            .joined(separator: " ")
            .prefix(200)
            .description
    }
}
