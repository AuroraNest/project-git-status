import Foundation

/// Git 仓库模型
struct GitRepository: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var path: String
    var parentProjectId: UUID
    var relativePath: String  // 相对于项目根目录的路径

    // 状态信息（运行时获取，不持久化）
    var status: GitStatus?
    var branches: [GitBranch]
    var currentBranch: String?
    var isLoading: Bool
    var lastError: String?

    init(id: UUID = UUID(), name: String, path: String, parentProjectId: UUID, relativePath: String = "") {
        self.id = id
        self.name = name
        self.path = path
        self.parentProjectId = parentProjectId
        self.relativePath = relativePath
        self.branches = []
        self.isLoading = false
    }

    // Codable - 只持久化基本信息
    enum CodingKeys: String, CodingKey {
        case id, name, path, parentProjectId, relativePath
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        path = try container.decode(String.self, forKey: .path)
        parentProjectId = try container.decode(UUID.self, forKey: .parentProjectId)
        relativePath = try container.decodeIfPresent(String.self, forKey: .relativePath) ?? ""
        branches = []
        isLoading = false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(path, forKey: .path)
        try container.encode(parentProjectId, forKey: .parentProjectId)
        try container.encode(relativePath, forKey: .relativePath)
    }

    // Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: GitRepository, rhs: GitRepository) -> Bool {
        lhs.id == rhs.id
    }
}
