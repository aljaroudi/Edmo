import Foundation

struct TaskSet: Identifiable, Codable, Hashable {
    var id: String { slug }
    var slug: String
    var prdFile: String
    var branchName: String
    var description: String
    var createdAt: Date
    var updatedAt: Date
    var stories: [Story]

    var completedCount: Int { stories.filter { $0.status == .done }.count }
    var totalCount: Int { stories.count }
    var progress: Double { totalCount == 0 ? 0 : Double(completedCount) / Double(totalCount) }
    var isAllDone: Bool { totalCount > 0 && completedCount == totalCount }

    enum CodingKeys: String, CodingKey {
        case slug
        case prdFile
        case branchName
        case description
        case createdAt
        case updatedAt
        case stories
        case userStories // Ralph format
    }

    init(slug: String, prdFile: String = "", branchName: String, description: String, createdAt: Date, updatedAt: Date, stories: [Story]) {
        self.slug = slug
        self.prdFile = prdFile
        self.branchName = branchName
        self.description = description
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.stories = stories
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        slug = (try? container.decode(String.self, forKey: .slug)) ?? ""
        prdFile = (try? container.decode(String.self, forKey: .prdFile)) ?? ""
        branchName = try container.decode(String.self, forKey: .branchName)
        description = try container.decode(String.self, forKey: .description)
        createdAt = (try? container.decode(Date.self, forKey: .createdAt)) ?? Date()
        updatedAt = (try? container.decode(Date.self, forKey: .updatedAt)) ?? Date()

        // Try internal format first ("stories"), then Ralph format ("userStories")
        if let s = try? container.decode([Story].self, forKey: .stories) {
            stories = s
        } else {
            stories = try container.decode([Story].self, forKey: .userStories)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(slug, forKey: .slug)
        try container.encode(prdFile, forKey: .prdFile)
        try container.encode(branchName, forKey: .branchName)
        try container.encode(description, forKey: .description)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(stories, forKey: .stories)
    }
}

struct Story: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var description: String
    var acceptanceCriteria: [String]
    var priority: Int
    var status: StoryStatus
    var issueNumber: Int?
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case id, title, description, acceptanceCriteria, priority
        case status, passes // "passes" is Ralph format
        case issueNumber, notes
    }

    init(id: String, title: String, description: String, acceptanceCriteria: [String], priority: Int, status: StoryStatus, issueNumber: Int? = nil, notes: String? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.acceptanceCriteria = acceptanceCriteria
        self.priority = priority
        self.status = status
        self.issueNumber = issueNumber
        self.notes = notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        acceptanceCriteria = try container.decode([String].self, forKey: .acceptanceCriteria)
        priority = try container.decode(Int.self, forKey: .priority)
        issueNumber = try? container.decode(Int.self, forKey: .issueNumber)
        notes = try? container.decode(String.self, forKey: .notes)

        // Try internal format first ("status"), then Ralph format ("passes": Bool)
        if let s = try? container.decode(StoryStatus.self, forKey: .status) {
            status = s
        } else if let passes = try? container.decode(Bool.self, forKey: .passes) {
            status = passes ? .done : .open
        } else {
            status = .open
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(acceptanceCriteria, forKey: .acceptanceCriteria)
        try container.encode(priority, forKey: .priority)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(issueNumber, forKey: .issueNumber)
        try container.encodeIfPresent(notes, forKey: .notes)
    }
}

enum StoryStatus: String, Codable {
    case open
    case done
}
