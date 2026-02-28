import Foundation

/// Git 仓库状态
struct GitStatus: Equatable {
    var currentBranch: String
    var aheadCount: Int
    var behindCount: Int
    var stagedFiles: [GitFile]
    var modifiedFiles: [GitFile]
    var untrackedFiles: [GitFile]
    var conflictedFiles: [GitFile]

    var totalChangedCount: Int {
        stagedFiles.count + modifiedFiles.count + untrackedFiles.count
    }

    var hasChanges: Bool {
        totalChangedCount > 0
    }

    var hasUnpushedCommits: Bool {
        aheadCount > 0
    }

    static let empty = GitStatus(
        currentBranch: "",
        aheadCount: 0,
        behindCount: 0,
        stagedFiles: [],
        modifiedFiles: [],
        untrackedFiles: [],
        conflictedFiles: []
    )
}
