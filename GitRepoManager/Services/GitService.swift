import Foundation

/// Git 服务 - 封装所有 Git 操作
actor GitService {
    private let runner = GitCommandRunner()

    // MARK: - 状态查询

    /// 获取仓库状态
    func getStatus(in directory: String) async throws -> GitStatus {
        // 获取当前分支（快速，2秒超时）
        let branchResult = try await runner.execute(
            ["rev-parse", "--abbrev-ref", "HEAD"],
            in: directory,
            timeout: 2.0
        )
        let currentBranch = branchResult.trimmingCharacters(in: .whitespacesAndNewlines)

        // 获取领先/落后数（可能慢，2秒超时，失败就跳过）
        var aheadCount = 0
        var behindCount = 0

        do {
            let aheadBehind = try await runner.execute(
                ["rev-list", "--left-right", "--count", "@{upstream}...HEAD"],
                in: directory,
                timeout: 2.0
            )
            let parts = aheadBehind.split(separator: "\t")
            if parts.count >= 2 {
                behindCount = Int(parts[0]) ?? 0
                aheadCount = Int(parts[1]) ?? 0
            }
        } catch {
            // 可能没有上游分支或超时，忽略错误
        }

        // 获取文件状态（可能慢，10秒超时）
        let statusOutput = try await runner.execute(
            ["status", "--porcelain=v2", "--untracked-files=all"],
            in: directory,
            timeout: 10.0
        )

        let files = parseStatusOutput(statusOutput)

        return GitStatus(
            currentBranch: currentBranch,
            aheadCount: aheadCount,
            behindCount: behindCount,
            stagedFiles: files.filter { $0.isStaged },
            modifiedFiles: files.filter { !$0.isStaged && $0.status != .untracked },
            untrackedFiles: files.filter { $0.status == .untracked },
            conflictedFiles: files.filter { $0.status == .conflicted }
        )
    }

    /// 解析 git status 输出
    private func parseStatusOutput(_ output: String) -> [GitFile] {
        var files: [GitFile] = []
        let lines = output.components(separatedBy: "\n")

        for line in lines where !line.isEmpty {
            if line.hasPrefix("1 ") || line.hasPrefix("2 ") {
                // 普通变更文件 (porcelain v2)
                let parts = line.components(separatedBy: " ")
                guard parts.count >= 9 else { continue }

                let xy = parts[1]
                let path = parts[8...].joined(separator: " ")

                let indexStatus = String(xy.prefix(1))
                let workStatus = String(xy.suffix(1))

                // 如果索引区有变更（已暂存）
                if indexStatus != "." {
                    files.append(GitFile(
                        path: path,
                        status: parseFileStatus(indexStatus),
                        isStaged: true
                    ))
                }

                // 如果工作区有变更（未暂存）
                if workStatus != "." {
                    files.append(GitFile(
                        path: path,
                        status: parseFileStatus(workStatus),
                        isStaged: false
                    ))
                }
            } else if line.hasPrefix("? ") {
                // 未跟踪文件
                let path = String(line.dropFirst(2))
                files.append(GitFile(
                    path: path,
                    status: .untracked,
                    isStaged: false
                ))
            } else if line.hasPrefix("u ") {
                // 冲突文件
                let parts = line.components(separatedBy: " ")
                if let path = parts.last {
                    files.append(GitFile(
                        path: path,
                        status: .conflicted,
                        isStaged: false
                    ))
                }
            }
        }

        return files
    }

    private func parseFileStatus(_ char: String) -> FileStatus {
        switch char {
        case "M": return .modified
        case "A": return .added
        case "D": return .deleted
        case "R": return .renamed
        case "C": return .copied
        case "?": return .untracked
        case "!": return .ignored
        case "U": return .conflicted
        default: return .modified
        }
    }

    // MARK: - 分支操作

    /// 获取所有分支
    func getBranches(in directory: String) async throws -> [GitBranch] {
        let output = try await runner.execute(
            ["branch", "-a", "--format=%(refname:short)|%(upstream:short)|%(HEAD)"],
            in: directory
        )

        var branches: [GitBranch] = []

        for line in output.components(separatedBy: "\n") where !line.isEmpty {
            let parts = line.components(separatedBy: "|")
            guard parts.count >= 3 else { continue }

            let name = parts[0]
            let tracking = parts[1].isEmpty ? nil : parts[1]
            let isCurrent = parts[2] == "*"
            let isRemote = name.hasPrefix("origin/") || name.contains("remotes/")

            // 跳过 HEAD 指针
            if name.contains("HEAD") { continue }

            branches.append(GitBranch(
                name: name,
                isRemote: isRemote,
                isCurrent: isCurrent,
                trackingBranch: tracking
            ))
        }

        return branches
    }

    /// 切换分支
    func checkout(branch: String, in directory: String) async throws {
        _ = try await runner.execute(
            ["checkout", branch],
            in: directory
        )
    }

    /// 创建新分支
    func createBranch(name: String, in directory: String, checkout: Bool = true) async throws {
        if checkout {
            _ = try await runner.execute(
                ["checkout", "-b", name],
                in: directory
            )
        } else {
            _ = try await runner.execute(
                ["branch", name],
                in: directory
            )
        }
    }

    /// 合并分支
    func merge(branch: String, in directory: String) async throws {
        _ = try await runner.execute(
            ["merge", branch],
            in: directory
        )
    }

    // MARK: - 暂存操作

    /// 暂存所有文件
    func stageAll(in directory: String) async throws {
        _ = try await runner.execute(
            ["add", "-A"],
            in: directory
        )
    }

    /// 暂存指定文件
    func stageFiles(_ paths: [String], in directory: String) async throws {
        guard !paths.isEmpty else { return }
        _ = try await runner.execute(
            ["add"] + paths,
            in: directory
        )
    }

    /// 取消暂存所有文件
    func unstageAll(in directory: String) async throws {
        _ = try await runner.execute(
            // Use pathspec form so unborn HEAD repos (no first commit yet) don't fail.
            ["reset", "HEAD", "--", "."],
            in: directory
        )
    }

    /// 取消暂存指定文件
    func unstageFiles(_ paths: [String], in directory: String) async throws {
        guard !paths.isEmpty else { return }
        _ = try await runner.execute(
            ["reset", "HEAD", "--"] + paths,
            in: directory
        )
    }

    // MARK: - 提交操作

    /// 提交
    func commit(message: String, in directory: String) async throws {
        _ = try await runner.execute(
            ["commit", "-m", message],
            in: directory
        )
    }

    // MARK: - 远程操作

    /// 拉取
    func pull(in directory: String) async throws {
        _ = try await runner.execute(
            ["pull"],
            in: directory
        )
    }

    /// 推送
    func push(in directory: String) async throws {
        _ = try await runner.execute(
            ["push"],
            in: directory
        )
    }

    /// 获取远程更新
    func fetch(in directory: String) async throws {
        _ = try await runner.execute(
            ["fetch", "--all"],
            in: directory
        )
    }

    // MARK: - Diff

    /// 获取文件 diff
    func getDiff(for file: GitFile, in directory: String) async throws -> String {
        let args: [String]

        if file.isStaged {
            args = ["diff", "--cached", "--", file.path]
        } else if file.status == .untracked {
            // 未跟踪文件显示文件内容
            let filePath = URL(fileURLWithPath: directory).appendingPathComponent(file.path)
            return try String(contentsOf: filePath, encoding: .utf8)
        } else {
            args = ["diff", "--", file.path]
        }

        return try await runner.execute(args, in: directory)
    }

    // MARK: - 执行任意命令

    /// 执行任意 git 命令
    func executeRawCommand(_ command: String, in directory: String) async throws -> String {
        let args = command.components(separatedBy: " ").filter { !$0.isEmpty }

        guard let firstArg = args.first else {
            throw GitError.commandFailed("命令不能为空")
        }

        var gitArgs: [String]
        if firstArg.lowercased() == "git" {
            gitArgs = Array(args.dropFirst())
        } else {
            gitArgs = args
        }

        return try await runner.execute(gitArgs, in: directory)
    }
}
