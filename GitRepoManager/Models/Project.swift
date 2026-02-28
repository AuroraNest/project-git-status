import Foundation

/// 项目模型 - 代表一个项目根目录
struct Project: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var path: String
    var repositories: [GitRepository]
    var isExpanded: Bool
    var isPinned: Bool
    var note: String
    var sortOrder: Int
    var lastScannedAt: Date?

    init(id: UUID = UUID(), name: String, path: String, isPinned: Bool = false, note: String = "", sortOrder: Int = 0) {
        self.id = id
        self.name = name
        self.path = path
        self.repositories = []
        self.isExpanded = true
        self.isPinned = isPinned
        self.note = note
        self.sortOrder = sortOrder
    }

    static func nameFromPath(_ path: String) -> String {
        return URL(fileURLWithPath: path).lastPathComponent
    }

    // Codable - 只持久化基本信息
    enum CodingKeys: String, CodingKey {
        case id, name, path, isExpanded, isPinned, note, sortOrder, lastScannedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        path = try container.decode(String.self, forKey: .path)
        isExpanded = try container.decodeIfPresent(Bool.self, forKey: .isExpanded) ?? true
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        lastScannedAt = try container.decodeIfPresent(Date.self, forKey: .lastScannedAt)
        repositories = []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(path, forKey: .path)
        try container.encode(isExpanded, forKey: .isExpanded)
        try container.encode(isPinned, forKey: .isPinned)
        try container.encode(note, forKey: .note)
        try container.encode(sortOrder, forKey: .sortOrder)
        try container.encodeIfPresent(lastScannedAt, forKey: .lastScannedAt)
    }
}
