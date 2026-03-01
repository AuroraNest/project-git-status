import Foundation

/// Git 提交记录
struct GitCommit: Identifiable, Hashable {
    let id: String           // commit hash (短，7位)
    let fullHash: String     // commit hash (完整，40位)
    let message: String      // 提交信息（首行）
    let author: String       // 作者
    let date: Date           // 提交时间
    let relativeDate: String // 相对时间 (如 "2 hours ago")

    /// 从 git log 输出行解析
    /// 格式: shortHash|fullHash|message|author|relativeDate|timestamp
    static func parse(from line: String) -> GitCommit? {
        let parts = line.components(separatedBy: "|")
        guard parts.count >= 6 else { return nil }

        let timestamp = TimeInterval(parts[5]) ?? Date().timeIntervalSince1970

        return GitCommit(
            id: parts[0],
            fullHash: parts[1],
            message: parts[2],
            author: parts[3],
            date: Date(timeIntervalSince1970: timestamp),
            relativeDate: parts[4]
        )
    }
}

/// 提交中变更的文件
struct CommitFile: Identifiable, Hashable {
    var id: String { path }
    let path: String
    let status: CommitFileStatus

    var fileName: String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    var statusIcon: String {
        switch status {
        case .added: return "plus.circle.fill"
        case .modified: return "pencil.circle.fill"
        case .deleted: return "minus.circle.fill"
        case .renamed: return "arrow.right.circle.fill"
        case .copied: return "doc.on.doc.fill"
        }
    }

    var statusColor: String {
        switch status {
        case .added: return "green"
        case .modified: return "orange"
        case .deleted: return "red"
        case .renamed: return "blue"
        case .copied: return "purple"
        }
    }
}

enum CommitFileStatus: String {
    case added = "A"
    case modified = "M"
    case deleted = "D"
    case renamed = "R"
    case copied = "C"

    static func from(_ char: String) -> CommitFileStatus {
        switch char.prefix(1) {
        case "A": return .added
        case "M": return .modified
        case "D": return .deleted
        case "R": return .renamed
        case "C": return .copied
        default: return .modified
        }
    }
}

/// 提交详情
struct CommitDetail {
    let fullHash: String
    let subject: String      // 提交标题
    let body: String         // 提交正文
    let author: String
    let authorEmail: String
    let relativeDate: String
    let date: Date
    let files: [CommitFile]
    let stats: String        // 统计信息（如 "3 files changed, 10 insertions(+), 5 deletions(-)"）

    static func parse(showOutput: String, filesOutput: String) -> CommitDetail {
        // 解析 show 输出的第一行（格式信息）
        let lines = showOutput.components(separatedBy: "\n")
        var fullHash = ""
        var subject = ""
        var body = ""
        var author = ""
        var authorEmail = ""
        var relativeDate = ""
        var timestamp: TimeInterval = Date().timeIntervalSince1970
        var stats = ""

        if let firstLine = lines.first {
            let parts = firstLine.components(separatedBy: "|")
            if parts.count >= 7 {
                fullHash = parts[0]
                subject = parts[1]
                body = parts[2]
                author = parts[3]
                authorEmail = parts[4]
                relativeDate = parts[5]
                timestamp = TimeInterval(parts[6]) ?? Date().timeIntervalSince1970
            }
        }

        // 解析统计信息（最后几行）
        for line in lines.reversed() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains("changed") && (trimmed.contains("insertion") || trimmed.contains("deletion")) {
                stats = trimmed
                break
            }
        }

        // 解析文件列表
        let files = filesOutput
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .compactMap { line -> CommitFile? in
                let parts = line.components(separatedBy: "\t")
                guard parts.count >= 2 else { return nil }
                let status = CommitFileStatus.from(parts[0])
                let path = parts[1]
                return CommitFile(path: path, status: status)
            }

        return CommitDetail(
            fullHash: fullHash,
            subject: subject,
            body: body,
            author: author,
            authorEmail: authorEmail,
            relativeDate: relativeDate,
            date: Date(timeIntervalSince1970: timestamp),
            files: files,
            stats: stats
        )
    }
}
