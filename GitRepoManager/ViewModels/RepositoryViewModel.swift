import SwiftUI
import Combine
import AppKit

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
    private let l10n = AppLocalization.shared

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
            operationMessage = l10n.t(.fetchedRemoteUpdates)
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
            operationMessage = l10n.t(.stagedAllFiles)
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
                operationMessage = l10n.t(.noModifiedFilesToStage)
                return
            }
            try await gitService.stageFiles(paths, in: repository.path)
            await loadStatus()
            operationMessage = l10n.stagedModifiedFilesCount(paths.count)
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
            operationMessage = l10n.stagedFilesCount(files.count)
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
            operationMessage = l10n.t(.unstagedAllFiles)
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
            operationMessage = l10n.t(.commitSuccess)
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
                operationMessage = l10n.t(.commitAndPushSuccess)
            } catch {
                await loadStatus()
                operationMessage = l10n.t(.commitSuccessButPushFailed)
                lastError = error.localizedDescription
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// 暂存/提交（可选推送）指定文件；如果 files 为空，请在调用方提前处理默认集合。
    /// 说明：通过 `git commit -- <paths>` 只提交目标文件，同时尽量不破坏其它已暂存内容。
    func stageCommitAndMaybePush(message: String, files: [GitFile], push: Bool) async {
        isOperating = true
        defer { isOperating = false }

        let targetFiles = files.filter { $0.status != .conflicted }
        let targetPaths = Array(Set(targetFiles.flatMap { file in
            var paths = [file.path]
            if file.status == .renamed, let oldPath = file.oldPath, !oldPath.isEmpty {
                paths.append(oldPath)
            }
            return paths
        }))

        guard !targetPaths.isEmpty else { return }

        do {
            // 未跟踪文件无法直接通过 commit pathspec 提交，需要先 add
            let untrackedPaths = targetFiles
                .filter { $0.status == .untracked }
                .map(\.path)
            if !untrackedPaths.isEmpty {
                try await gitService.stageFiles(untrackedPaths, in: repository.path)
            }

            try await gitService.commit(message: message, paths: targetPaths, in: repository.path)

            if push {
                do {
                    try await gitService.push(in: repository.path)
                    await loadStatus()
                    operationMessage = l10n.t(.commitAndPushSuccess)
                    lastError = nil
                } catch {
                    await loadStatus()
                    operationMessage = l10n.t(.commitSuccessButPushFailed)
                    lastError = error.localizedDescription
                }
            } else {
                await loadStatus()
                operationMessage = l10n.t(.commitSuccess)
                lastError = nil
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
            operationMessage = l10n.t(.pullSuccess)
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
            operationMessage = l10n.t(.pushSuccess)
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
            operationMessage = l10n.switchedToBranch(branch.name)
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
            operationMessage = l10n.createdAndSwitchedToBranch(localName)
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
            operationMessage = l10n.createdBranch(name)
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
            operationMessage = l10n.mergedBranch(branch.name)
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Diff

    func getDiff(for file: GitFile) async -> String {
        do {
            return try await gitService.getDiff(for: file, in: repository.path)
        } catch {
            return l10n.unableToGetDiff(error.localizedDescription)
        }
    }

    func discardChanges(for file: GitFile) async {
        isOperating = true
        defer { isOperating = false }

        do {
            try await gitService.discardChanges([file.path], in: repository.path)
            await loadStatus()
            operationMessage = l10n.t(.discardedChanges)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func addToGitignore(path: String) async {
        isOperating = true
        defer { isOperating = false }

        do {
            let gitignoreURL = URL(fileURLWithPath: repository.path).appendingPathComponent(".gitignore")
            let normalizedLine = gitignorePattern(for: path)
            guard !normalizedLine.isEmpty else { return }

            var existing = (try? String(contentsOf: gitignoreURL, encoding: .utf8)) ?? ""
            let lines = Set(existing.split(separator: "\n", omittingEmptySubsequences: false).map { String($0) })
            guard !lines.contains(normalizedLine) else { return }

            if !existing.isEmpty && !existing.hasSuffix("\n") {
                existing.append("\n")
            }
            existing.append(normalizedLine)
            existing.append("\n")
            try existing.write(to: gitignoreURL, atomically: true, encoding: .utf8)

            await loadStatus()
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func gitignorePattern(for path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let fileName = URL(fileURLWithPath: trimmed).lastPathComponent
        if fileName == ".DS_Store" {
            return ".DS_Store"
        }

        return trimmed
    }

    func openFileAtHEAD(_ file: GitFile) {
        let headPath: String
        if file.status == .renamed, let oldPath = file.oldPath, !oldPath.isEmpty {
            headPath = oldPath
        } else {
            headPath = file.path
        }

        Task {
            do {
                let content = try await gitService.showFileAtHEAD(path: headPath, in: repository.path)
                let tempDir = FileManager.default.temporaryDirectory
                    .appendingPathComponent("gitrepomanager-head-files", isDirectory: true)
                try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

                let baseName = URL(fileURLWithPath: file.fileName).deletingPathExtension().lastPathComponent
                let ext = URL(fileURLWithPath: file.fileName).pathExtension
                let fileName = ext.isEmpty ? "\(baseName)-HEAD" : "\(baseName)-HEAD.\(ext)"
                let outURL = tempDir.appendingPathComponent(fileName)
                try content.write(to: outURL, atomically: true, encoding: .utf8)
                NSWorkspace.shared.open(outURL)
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    func clearMessages() {
        operationMessage = nil
        lastError = nil
    }
}
