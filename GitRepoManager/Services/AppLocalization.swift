import Foundation
import Combine

enum AppLanguage: String, CaseIterable, Codable, Identifiable {
    case chinese = "zh-Hans"
    case english = "en"

    var id: String { rawValue }

    var optionLabel: String {
        switch self {
        case .chinese:
            return "中文"
        case .english:
            return "English"
        }
    }
}

enum LocalizedKey: Hashable {
    case language
    case refresh
    case refreshAllRepositories
    case addProject
    case addProjectEllipsis
    case addProjectDirectoryHelp
    case error
    case confirm
    case refreshing
    case noProjectsYet
    case clickPlusToAddProjectDirectory
    case selectRepositoryToViewDetails
    case selectRepositoryFromSidebar
    case gitRepositoryManager
    case rescan
    case removeProject
    case showInFinder
    case openInTerminal
    case refreshStatus
    case changes
    case branches
    case terminal
    case operationFailed
    case pull
    case pullHelp
    case push
    case pushHelp
    case loading
    case noDiffContent
    case inputGitCommand
    case clearOutput
    case openChanges
    case openFile
    case openFileHead
    case discardChanges
    case discardedChanges
    case stageChanges
    case unstageChanges
    case addToGitignore
    case addProjectTitle
    case chooseProjectRootDirectory
    case noDirectorySelected
    case choose
    case chooseProjectDirectory
    case chooseDirectoryContainingGitRepos
    case cancel
    case create
    case merge
    case stageAll
    case stageModifiedOnly
    case stageSelected
    case unstageAll
    case commitMessage
    case enterCommitMessage
    case commit
    case commitAndPush
    case selectFileToViewDiff
    case noFileChanges
    case staged
    case modified
    case selectAll
    case deselectAll
    case untracked
    case newBranch
    case mergeBranch
    case fetchRemote
    case localBranches
    case remoteBranches
    case noBranchesFound
    case tracking
    case checkout
    case switchBranch
    case current
    case branchName
    case selectBranch
    case pleaseChoose
    case defaultProject
    case noRepositoriesUnderDefaultProject
    case targetRepositoryOnlyChanged
    case noChangedRepositoriesRefreshFirst
    case viewDetails
    case finder
    case changeTips
    case collapse
    case expand
    case noModifiedDirectories
    case modifiedDirectories
    case filePreview
    case noStatusDataRefreshToSeeChangedDirectories
    case commitLogModifiedOnly
    case enterCommitLog
    case quickCommitPushModified
    case gitQuickPanel
    case closePanel
    case openMainWindowToAddProject
    case repositoryRootDirectory
    case gitStatus
    case fetchedRemoteUpdates
    case stagedAllFiles
    case noModifiedFilesToStage
    case unstagedAllFiles
    case commitSuccess
    case commitAndPushSuccess
    case commitSuccessButPushFailed
    case pullSuccess
    case pushSuccess
    case scanRepositoriesFailed
    case enterCommitLogMessage
    case targetRepositoryNotFound
    case repoBusyRetryLater
    case noModifiedFilesToCommit
    case commitOrPushFailed
    case unableToGetDiff
    case gitCommandFailed
    case notAGitRepository
    case mergeConflict
    case detachedHead
    case networkError
    case unknownError
    case commandTimeout
    case commandCannotBeEmpty
    case fileStatusModified
    case fileStatusAdded
    case fileStatusDeleted
    case fileStatusRenamed
    case fileStatusCopied
    case fileStatusUntracked
    case fileStatusIgnored
    case fileStatusConflicted
}

final class AppLocalization: ObservableObject {
    static let shared = AppLocalization()

    @Published var language: AppLanguage {
        didSet {
            guard oldValue != language else { return }
            persistence.saveLanguage(language)
        }
    }

    private let persistence = PersistenceService.shared

    private init() {
        language = persistence.loadLanguage() ?? .chinese
    }

    func t(_ key: LocalizedKey) -> String {
        translations[language]?[key] ?? translations[.chinese]?[key] ?? ""
    }

    func repositoriesCount(_ count: Int) -> String {
        switch language {
        case .chinese:
            return "\(count) 个仓库"
        case .english:
            return "\(count) repositories"
        }
    }

    func stagedModifiedFilesCount(_ count: Int) -> String {
        switch language {
        case .chinese:
            return "已暂存 \(count) 个已修改文件"
        case .english:
            return "Staged \(count) modified files"
        }
    }

    func stagedFilesCount(_ count: Int) -> String {
        switch language {
        case .chinese:
            return "已暂存 \(count) 个文件"
        case .english:
            return "Staged \(count) files"
        }
    }

    func quickCommitPushSuccess(_ count: Int) -> String {
        switch language {
        case .chinese:
            return "提交并推送成功（\(count) 个文件）"
        case .english:
            return "Commit and push succeeded (\(count) files)"
        }
    }

    func trackingBranch(_ branch: String) -> String {
        switch language {
        case .chinese:
            return "跟踪: \(branch)"
        case .english:
            return "Tracking: \(branch)"
        }
    }

    func mergeSelectedBranchInto(_ currentBranch: String) -> String {
        switch language {
        case .chinese:
            return "将选择的分支合并到 \(currentBranch)"
        case .english:
            return "Merge the selected branch into \(currentBranch)"
        }
    }

    func scanRepositoriesFailed(_ message: String) -> String {
        switch language {
        case .chinese:
            return "扫描仓库失败: \(message)"
        case .english:
            return "Failed to scan repositories: \(message)"
        }
    }

    func switchedToBranch(_ branch: String) -> String {
        switch language {
        case .chinese:
            return "已切换到分支: \(branch)"
        case .english:
            return "Switched to branch: \(branch)"
        }
    }

    func createdAndSwitchedToBranch(_ branch: String) -> String {
        switch language {
        case .chinese:
            return "已创建并切换到分支: \(branch)"
        case .english:
            return "Created and switched to branch: \(branch)"
        }
    }

    func createdBranch(_ branch: String) -> String {
        switch language {
        case .chinese:
            return "已创建分支: \(branch)"
        case .english:
            return "Created branch: \(branch)"
        }
    }

    func mergedBranch(_ branch: String) -> String {
        switch language {
        case .chinese:
            return "已合并分支: \(branch)"
        case .english:
            return "Merged branch: \(branch)"
        }
    }

    func unableToGetDiff(_ message: String) -> String {
        switch language {
        case .chinese:
            return "无法获取差异: \(message)"
        case .english:
            return "Unable to load diff: \(message)"
        }
    }

    func gitCommandFailed(_ message: String) -> String {
        switch language {
        case .chinese:
            return "Git 命令执行失败: \(message)"
        case .english:
            return "Git command failed: \(message)"
        }
    }

    func networkError(_ message: String) -> String {
        switch language {
        case .chinese:
            return "网络错误: \(message)"
        case .english:
            return "Network error: \(message)"
        }
    }

    func unknownError(_ message: String) -> String {
        switch language {
        case .chinese:
            return "未知错误: \(message)"
        case .english:
            return "Unknown error: \(message)"
        }
    }

    func gitTerminalHeader(_ repoName: String) -> String {
        switch language {
        case .chinese:
            return "Git 终端 - \(repoName)"
        case .english:
            return "Git Terminal - \(repoName)"
        }
    }

    func fileStatusDisplayName(_ status: FileStatus) -> String {
        switch status {
        case .modified:
            return t(.fileStatusModified)
        case .added:
            return t(.fileStatusAdded)
        case .deleted:
            return t(.fileStatusDeleted)
        case .renamed:
            return t(.fileStatusRenamed)
        case .copied:
            return t(.fileStatusCopied)
        case .untracked:
            return t(.fileStatusUntracked)
        case .ignored:
            return t(.fileStatusIgnored)
        case .conflicted:
            return t(.fileStatusConflicted)
        }
    }

    private let translations: [AppLanguage: [LocalizedKey: String]] = [
        .chinese: [
            .language: "语言",
            .refresh: "刷新",
            .refreshAllRepositories: "刷新所有仓库",
            .addProject: "添加项目",
            .addProjectEllipsis: "添加项目...",
            .addProjectDirectoryHelp: "添加项目目录",
            .error: "错误",
            .confirm: "确定",
            .refreshing: "刷新中...",
            .noProjectsYet: "还没有添加项目",
            .clickPlusToAddProjectDirectory: "点击上方 + 按钮添加项目目录",
            .selectRepositoryToViewDetails: "选择一个仓库查看详情",
            .selectRepositoryFromSidebar: "从左侧列表选择仓库",
            .gitRepositoryManager: "Git 仓库管理",
            .rescan: "重新扫描",
            .removeProject: "移除项目",
            .showInFinder: "在 Finder 中显示",
            .openInTerminal: "在终端中打开",
            .refreshStatus: "刷新状态",
            .changes: "变更",
            .branches: "分支",
            .terminal: "终端",
            .operationFailed: "操作失败",
            .pull: "拉取",
            .pullHelp: "从远程拉取更新",
            .push: "推送",
            .pushHelp: "推送到远程",
            .loading: "加载中...",
            .noDiffContent: "没有差异内容",
            .inputGitCommand: "输入 git 命令...",
            .clearOutput: "清空输出",
            .openChanges: "打开更改",
            .openFile: "打开文件",
            .openFileHead: "打开文件 (HEAD)",
            .discardChanges: "放弃更改",
            .discardedChanges: "已放弃更改",
            .stageChanges: "暂存更改",
            .unstageChanges: "取消暂存",
            .addToGitignore: "添加到 .gitignore",
            .addProjectTitle: "添加项目",
            .chooseProjectRootDirectory: "选择项目根目录，应用会自动扫描其中的 Git 仓库",
            .noDirectorySelected: "未选择目录",
            .choose: "选择",
            .chooseProjectDirectory: "选择项目目录",
            .chooseDirectoryContainingGitRepos: "选择包含 Git 仓库的项目目录",
            .cancel: "取消",
            .create: "创建",
            .merge: "合并",
            .stageAll: "暂存全部",
            .stageModifiedOnly: "暂存已修改",
            .stageSelected: "暂存选中",
            .unstageAll: "取消全部",
            .commitMessage: "提交信息",
            .enterCommitMessage: "输入提交信息...",
            .commit: "提交",
            .commitAndPush: "提交并推送",
            .selectFileToViewDiff: "选择文件查看差异",
            .noFileChanges: "没有文件变更",
            .staged: "已暂存",
            .modified: "已修改",
            .selectAll: "全选",
            .deselectAll: "取消全选",
            .untracked: "未跟踪",
            .newBranch: "新建分支",
            .mergeBranch: "合并分支",
            .fetchRemote: "获取远程",
            .localBranches: "本地分支",
            .remoteBranches: "远程分支",
            .noBranchesFound: "没有找到分支",
            .tracking: "跟踪",
            .checkout: "检出",
            .switchBranch: "切换",
            .current: "当前",
            .branchName: "分支名称",
            .selectBranch: "选择分支",
            .pleaseChoose: "请选择...",
            .defaultProject: "默认项目",
            .noRepositoriesUnderDefaultProject: "默认项目下没有仓库",
            .targetRepositoryOnlyChanged: "目标仓库（仅显示有修改）",
            .noChangedRepositoriesRefreshFirst: "当前没有有修改的仓库，先点“刷新”",
            .viewDetails: "查看详情",
            .finder: "Finder",
            .changeTips: "变更提示",
            .collapse: "收起",
            .expand: "展开",
            .noModifiedDirectories: "当前没有已修改目录",
            .modifiedDirectories: "已修改目录：",
            .filePreview: "文件预览：",
            .noStatusDataRefreshToSeeChangedDirectories: "暂无状态数据，点“刷新”即可看到变更目录",
            .commitLogModifiedOnly: "提交日志（仅提交并推送已修改文件）",
            .enterCommitLog: "输入提交日志...",
            .quickCommitPushModified: "提交并推送已修改",
            .gitQuickPanel: "Git 快捷面板",
            .closePanel: "收起",
            .openMainWindowToAddProject: "打开主窗口添加项目",
            .repositoryRootDirectory: "仓库根目录",
            .gitStatus: "Git 仓库状态",
            .fetchedRemoteUpdates: "已获取远程更新",
            .stagedAllFiles: "已暂存所有文件",
            .noModifiedFilesToStage: "没有可暂存的已修改文件",
            .unstagedAllFiles: "已取消暂存所有文件",
            .commitSuccess: "提交成功",
            .commitAndPushSuccess: "提交并推送成功",
            .commitSuccessButPushFailed: "提交成功，但推送失败",
            .pullSuccess: "拉取成功",
            .pushSuccess: "推送成功",
            .scanRepositoriesFailed: "扫描仓库失败",
            .enterCommitLogMessage: "请输入提交日志",
            .targetRepositoryNotFound: "未找到目标仓库",
            .repoBusyRetryLater: "仓库正在处理中，请稍后重试",
            .noModifiedFilesToCommit: "没有可提交的已修改文件",
            .commitOrPushFailed: "提交或推送失败",
            .unableToGetDiff: "无法获取差异",
            .gitCommandFailed: "Git 命令执行失败",
            .notAGitRepository: "当前目录不是 Git 仓库",
            .mergeConflict: "存在合并冲突，请先解决冲突",
            .detachedHead: "当前处于分离头指针状态",
            .networkError: "网络错误",
            .unknownError: "未知错误",
            .commandTimeout: "命令超时",
            .commandCannotBeEmpty: "命令不能为空",
            .fileStatusModified: "已修改",
            .fileStatusAdded: "已添加",
            .fileStatusDeleted: "已删除",
            .fileStatusRenamed: "已重命名",
            .fileStatusCopied: "已复制",
            .fileStatusUntracked: "未跟踪",
            .fileStatusIgnored: "已忽略",
            .fileStatusConflicted: "冲突"
        ],
        .english: [
            .language: "Language",
            .refresh: "Refresh",
            .refreshAllRepositories: "Refresh All Repositories",
            .addProject: "Add Project",
            .addProjectEllipsis: "Add Project...",
            .addProjectDirectoryHelp: "Add a project directory",
            .error: "Error",
            .confirm: "OK",
            .refreshing: "Refreshing...",
            .noProjectsYet: "No projects added yet",
            .clickPlusToAddProjectDirectory: "Click the + button above to add a project directory",
            .selectRepositoryToViewDetails: "Select a repository to view details",
            .selectRepositoryFromSidebar: "Choose a repository from the sidebar",
            .gitRepositoryManager: "Git Repository Manager",
            .rescan: "Rescan",
            .removeProject: "Remove Project",
            .showInFinder: "Show in Finder",
            .openInTerminal: "Open in Terminal",
            .refreshStatus: "Refresh Status",
            .changes: "Changes",
            .branches: "Branches",
            .terminal: "Terminal",
            .operationFailed: "Operation Failed",
            .pull: "Pull",
            .pullHelp: "Pull updates from remote",
            .push: "Push",
            .pushHelp: "Push to remote",
            .loading: "Loading...",
            .noDiffContent: "No diff content",
            .inputGitCommand: "Enter a git command...",
            .clearOutput: "Clear output",
            .openChanges: "Open Changes",
            .openFile: "Open File",
            .openFileHead: "Open File (HEAD)",
            .discardChanges: "Discard Changes",
            .discardedChanges: "Changes discarded",
            .stageChanges: "Stage Changes",
            .unstageChanges: "Unstage",
            .addToGitignore: "Add to .gitignore",
            .addProjectTitle: "Add Project",
            .chooseProjectRootDirectory: "Select a project root directory and the app will scan its Git repositories automatically",
            .noDirectorySelected: "No directory selected",
            .choose: "Choose",
            .chooseProjectDirectory: "Choose Project Directory",
            .chooseDirectoryContainingGitRepos: "Choose a project directory containing Git repositories",
            .cancel: "Cancel",
            .create: "Create",
            .merge: "Merge",
            .stageAll: "Stage All",
            .stageModifiedOnly: "Stage Modified",
            .stageSelected: "Stage Selected",
            .unstageAll: "Unstage All",
            .commitMessage: "Commit Message",
            .enterCommitMessage: "Enter commit message...",
            .commit: "Commit",
            .commitAndPush: "Commit & Push",
            .selectFileToViewDiff: "Select a file to view its diff",
            .noFileChanges: "No file changes",
            .staged: "Staged",
            .modified: "Modified",
            .selectAll: "Select All",
            .deselectAll: "Deselect All",
            .untracked: "Untracked",
            .newBranch: "New Branch",
            .mergeBranch: "Merge Branch",
            .fetchRemote: "Fetch",
            .localBranches: "Local Branches",
            .remoteBranches: "Remote Branches",
            .noBranchesFound: "No branches found",
            .tracking: "Tracking",
            .checkout: "Checkout",
            .switchBranch: "Switch",
            .current: "Current",
            .branchName: "Branch name",
            .selectBranch: "Select Branch",
            .pleaseChoose: "Please choose...",
            .defaultProject: "Default Project",
            .noRepositoriesUnderDefaultProject: "No repositories in the default project",
            .targetRepositoryOnlyChanged: "Target Repository (changed only)",
            .noChangedRepositoriesRefreshFirst: "No changed repositories right now. Click Refresh first.",
            .viewDetails: "View Details",
            .finder: "Finder",
            .changeTips: "Change Tips",
            .collapse: "Collapse",
            .expand: "Expand",
            .noModifiedDirectories: "No modified directories",
            .modifiedDirectories: "Modified directories:",
            .filePreview: "File preview:",
            .noStatusDataRefreshToSeeChangedDirectories: "No status data yet. Click Refresh to view changed directories.",
            .commitLogModifiedOnly: "Commit Log (commit and push modified files only)",
            .enterCommitLog: "Enter commit log...",
            .quickCommitPushModified: "Commit & Push Modified",
            .gitQuickPanel: "Git Quick Panel",
            .closePanel: "Close",
            .openMainWindowToAddProject: "Open the main window to add a project",
            .repositoryRootDirectory: "Repository root",
            .gitStatus: "Git repository status",
            .fetchedRemoteUpdates: "Fetched remote updates",
            .stagedAllFiles: "Staged all files",
            .noModifiedFilesToStage: "No modified files to stage",
            .unstagedAllFiles: "Unstaged all files",
            .commitSuccess: "Commit succeeded",
            .commitAndPushSuccess: "Commit and push succeeded",
            .commitSuccessButPushFailed: "Commit succeeded, but push failed",
            .pullSuccess: "Pull succeeded",
            .pushSuccess: "Push succeeded",
            .scanRepositoriesFailed: "Failed to scan repositories",
            .enterCommitLogMessage: "Please enter a commit log",
            .targetRepositoryNotFound: "Target repository not found",
            .repoBusyRetryLater: "Repository is busy. Please try again later.",
            .noModifiedFilesToCommit: "No modified files to commit",
            .commitOrPushFailed: "Commit or push failed",
            .unableToGetDiff: "Unable to load diff",
            .gitCommandFailed: "Git command failed",
            .notAGitRepository: "The current directory is not a Git repository",
            .mergeConflict: "There are merge conflicts. Resolve them first.",
            .detachedHead: "The repository is in detached HEAD state",
            .networkError: "Network error",
            .unknownError: "Unknown error",
            .commandTimeout: "Command timed out",
            .commandCannotBeEmpty: "Command cannot be empty",
            .fileStatusModified: "Modified",
            .fileStatusAdded: "Added",
            .fileStatusDeleted: "Deleted",
            .fileStatusRenamed: "Renamed",
            .fileStatusCopied: "Copied",
            .fileStatusUntracked: "Untracked",
            .fileStatusIgnored: "Ignored",
            .fileStatusConflicted: "Conflicted"
        ]
    ]
}
