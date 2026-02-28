import SwiftUI
import Combine

@MainActor
class RepositoryViewModel: ObservableObject {
    let repository: GitRepository

    @Published var status: GitStatus?
    @Published var branches: [GitBranch] = []
    @Published var isLoading = false
    @Published var isOperating = false
    @Published var lastError: String?
    @Published var operationMessage: String?

    private let gitService = GitService()

    var localBranches: [GitBranch] {
        branches.filter { !$0.isRemote }
    }

    var remoteBranches: [GitBranch] {
        branches.filter { $0.isRemote }
    }

    var unstageableFiles: [GitFile] {
        (status?.modifiedFiles ?? []) + (status?.untrackedFiles ?? [])
    }

    init(repository: GitRepository) {
        self.repository = repository
        self.status = repository.status
    }

    // MARK: - 状态加载

    func loadStatus() async {
        isLoading = true
        defer { isLoading = false }

        do {
            status = try await gitService.getStatus(in: repository.path)
            branches = try await gitService.getBranches(in: repository.path)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func fetchBranches() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await gitService.fetch(in: repository.path)
            branches = try await gitService.getBranches(in: repository.path)
            operationMessage = "已获取远程更新"
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - 暂存操作

    func stageAll() async {
        isOperating = true
        defer { isOperating = false }

        do {
            try await gitService.stageAll(in: repository.path)
            await loadStatus()
            operationMessage = "已暂存所有文件"
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// 仅暂存「已修改」文件（不包含未跟踪文件）
    func stageModifiedOnly() async {
        isOperating = true
        defer { isOperating = false }

        do {
            let modifiedFiles = status?.modifiedFiles ?? []
            let paths = modifiedFiles.map { $0.path }
            guard !paths.isEmpty else {
                operationMessage = "没有可暂存的已修改文件"
                return
            }
            try await gitService.stageFiles(paths, in: repository.path)
            await loadStatus()
            operationMessage = "已暂存 \(paths.count) 个已修改文件"
        } catch {
            lastError = error.localizedDescription
        }
    }

    func stageFiles(_ files: [GitFile]) async {
        isOperating = true
        defer { isOperating = false }

        do {
            let paths = files.map { $0.path }
            try await gitService.stageFiles(paths, in: repository.path)
            await loadStatus()
            operationMessage = "已暂存 \(files.count) 个文件"
        } catch {
            lastError = error.localizedDescription
        }
    }

    func unstageAll() async {
        isOperating = true
        defer { isOperating = false }

        do {
            try await gitService.unstageAll(in: repository.path)
            await loadStatus()
            operationMessage = "已取消暂存所有文件"
        } catch {
            lastError = error.localizedDescription
        }
    }

    func unstageFiles(_ files: [GitFile]) async {
        isOperating = true
        defer { isOperating = false }

        do {
            let paths = files.map { $0.path }
            try await gitService.unstageFiles(paths, in: repository.path)
            await loadStatus()
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - 提交操作

    func commit(message: String) async {
        isOperating = true
        defer { isOperating = false }

        do {
            try await gitService.commit(message: message, in: repository.path)
            await loadStatus()
            operationMessage = "提交成功"
        } catch {
            lastError = error.localizedDescription
        }
    }

    func commitAndPush(message: String) async {
        isOperating = true
        defer { isOperating = false }

        do {
            try await gitService.commit(message: message, in: repository.path)
            do {
                try await gitService.push(in: repository.path)
                await loadStatus()
                operationMessage = "提交并推送成功"
            } catch {
                await loadStatus()
                operationMessage = "提交成功，但推送失败"
                lastError = error.localizedDescription
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - 远程操作

    func pull() async {
        isOperating = true
        defer { isOperating = false }

        do {
            try await gitService.pull(in: repository.path)
            await loadStatus()
            operationMessage = "拉取成功"
        } catch {
            lastError = error.localizedDescription
        }
    }

    func push() async {
        isOperating = true
        defer { isOperating = false }

        do {
            try await gitService.push(in: repository.path)
            await loadStatus()
            operationMessage = "推送成功"
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - 分支操作

    func checkoutBranch(_ branch: GitBranch) async {
        isOperating = true
        defer { isOperating = false }

        do {
            try await gitService.checkout(branch: branch.name, in: repository.path)
            await loadStatus()
            operationMessage = "已切换到分支: \(branch.name)"
        } catch {
            lastError = error.localizedDescription
        }
    }

    func checkoutRemoteBranch(_ branch: GitBranch) async {
        isOperating = true
        defer { isOperating = false }

        do {
            let localName = branch.name.replacingOccurrences(of: "origin/", with: "")
            try await gitService.createBranch(name: localName, in: repository.path)
            await loadStatus()
            operationMessage = "已创建并切换到分支: \(localName)"
        } catch {
            lastError = error.localizedDescription
        }
    }

    func createBranch(name: String) async {
        isOperating = true
        defer { isOperating = false }

        do {
            try await gitService.createBranch(name: name, in: repository.path)
            await loadStatus()
            operationMessage = "已创建分支: \(name)"
        } catch {
            lastError = error.localizedDescription
        }
    }

    func mergeBranch(_ branch: GitBranch) async {
        isOperating = true
        defer { isOperating = false }

        do {
            try await gitService.merge(branch: branch.name, in: repository.path)
            await loadStatus()
            operationMessage = "已合并分支: \(branch.name)"
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Diff

    func getDiff(for file: GitFile) async -> String {
        do {
            return try await gitService.getDiff(for: file, in: repository.path)
        } catch {
            return "无法获取差异: \(error.localizedDescription)"
        }
    }

    func clearMessages() {
        operationMessage = nil
        lastError = nil
    }
}
