import Foundation
import SwiftUI

/// 文件变更状态
enum FileStatus: String, Codable {
    case modified = "M"
    case added = "A"
    case deleted = "D"
    case renamed = "R"
    case copied = "C"
    case untracked = "?"
    case ignored = "!"
    case conflicted = "U"

    var displayName: String {
        AppLocalization.shared.fileStatusDisplayName(self)
    }

    var iconName: String {
        switch self {
        case .modified: return "pencil.circle.fill"
        case .added: return "plus.circle.fill"
        case .deleted: return "minus.circle.fill"
        case .renamed: return "arrow.right.circle.fill"
        case .copied: return "doc.on.doc.fill"
        case .untracked: return "questionmark.circle.fill"
        case .ignored: return "eye.slash.circle.fill"
        case .conflicted: return "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .modified: return .orange
        case .added: return .green
        case .deleted: return .red
        case .renamed: return .blue
        case .copied: return .cyan
        case .untracked: return .gray
        case .ignored: return .secondary
        case .conflicted: return .red
        }
    }
}

/// Git 文件模型
struct GitFile: Identifiable, Equatable, Hashable {
    let id: UUID
    var path: String
    var status: FileStatus
    var isStaged: Bool
    var oldPath: String?

    init(id: UUID = UUID(), path: String, status: FileStatus, isStaged: Bool = false, oldPath: String? = nil) {
        self.id = id
        self.path = path
        self.status = status
        self.isStaged = isStaged
        self.oldPath = oldPath
    }

    var fileName: String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    var directoryPath: String {
        let dir = URL(fileURLWithPath: path).deletingLastPathComponent().relativePath
        return dir.isEmpty || dir == "." ? "" : dir
    }
}
