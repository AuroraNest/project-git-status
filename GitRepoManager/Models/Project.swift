import Foundation

/// 项目模型 - 代表一个项目根目录
struct Project: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var path: String
    var repositories: [GitRepository]
    var isExpanded: Bool
    var lastScannedAt: Date?

    init(id: UUID = UUID(), name: String, path: String) {
        self.id = id
        self.name = name
        self.path = path
        self.repositories = []
        self.isExpanded = true
    }

    static func nameFromPath(_ path: String) -> String {
        return URL(fileURLWithPath: path).lastPathComponent
    }

    // Codable - 只持久化基本信息
    enum CodingKeys: String, CodingKey {
        case id, name, path, isExpanded, lastScannedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        path = try container.decode(String.self, forKey: .path)
        isExpanded = try container.decodeIfPresent(Bool.self, forKey: .isExpanded) ?? true
        lastScannedAt = try container.decodeIfPresent(Date.self, forKey: .lastScannedAt)
        repositories = []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(path, forKey: .path)
        try container.encode(isExpanded, forKey: .isExpanded)
        try container.encodeIfPresent(lastScannedAt, forKey: .lastScannedAt)
    }
}
