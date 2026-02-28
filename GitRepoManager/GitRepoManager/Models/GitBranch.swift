import Foundation

/// Git 分支模型
struct GitBranch: Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String
    var isRemote: Bool
    var isCurrent: Bool
    var trackingBranch: String?

    init(id: UUID = UUID(), name: String, isRemote: Bool = false, isCurrent: Bool = false, trackingBranch: String? = nil) {
        self.id = id
        self.name = name
        self.isRemote = isRemote
        self.isCurrent = isCurrent
        self.trackingBranch = trackingBranch
    }

    var displayName: String {
        if isRemote {
            return name.replacingOccurrences(of: "origin/", with: "")
        }
        return name
    }
}
