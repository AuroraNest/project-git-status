import Foundation

/// Git 服务 - 封装所有 Git 操作
actor GitService {
    private let runner = GitCommandRunner()

    private struct BranchStatusInfo {
        let currentBranch: String
        let aheadCount: Int
        let behindCount: Int
    }

    struct PullSummary {
        let isAlreadyUpToDate: Bool
        let commitRange: String?
        let changedFilesCount: Int?
        let insertions: Int?
        let deletions: Int?
    }

    // MARK: - 状态查询

    /// 获取仓库状态
    func getStatus(in directory: String) async throws -> GitStatus {
        // 一次性获取分支、ahead/behind 和文件状态。
        // `--branch` 头信息同时覆盖正常分支、无提交仓库与 detached HEAD 三种场景，
        // 避免单独调用 `rev-parse HEAD` / `rev-list @{upstream}...HEAD` 的脆弱性。
        let statusOutput = try await runner.execute(
            // `normal` 会把大目录折叠为 `dir/`，性能比 `all` 更好，避免频繁“转圈”
            ["-c", "core.quotepath=false", "status", "--porcelain=v2", "--branch", "--untracked-files=normal"],
            in: directory,
            timeout: 10.0
        )

        let branchInfo = parseBranchStatusInfo(statusOutput)
        let files = parseStatusOutput(statusOutput)

        return GitStatus(
            currentBranch: branchInfo.currentBranch,
            aheadCount: branchInfo.aheadCount,
            behindCount: branchInfo.behindCount,
            stagedFiles: files.filter { $0.isStaged },
            modifiedFiles: files.filter { !$0.isStaged && $0.status != .untracked },
            untrackedFiles: files.filter { $0.status == .untracked },
            conflictedFiles: files.filter { $0.status == .conflicted }
        )
    }

    private func parseBranchStatusInfo(_ output: String) -> BranchStatusInfo {
        var branchHead = ""
        var branchOID = ""
        var aheadCount = 0
        var behindCount = 0

        for rawLine in output.split(whereSeparator: \.isNewline) {
            let line = String(rawLine)

            if line.hasPrefix("# branch.head ") {
                branchHead = String(line.dropFirst("# branch.head ".count))
            } else if line.hasPrefix("# branch.oid ") {
                branchOID = String(line.dropFirst("# branch.oid ".count))
            } else if line.hasPrefix("# branch.ab ") {
                let counts = line
                    .dropFirst("# branch.ab ".count)
                    .split(separator: " ")

                for count in counts {
                    if count.hasPrefix("+") {
                        aheadCount = Int(count.dropFirst()) ?? 0
                    } else if count.hasPrefix("-") {
                        behindCount = Int(count.dropFirst()) ?? 0
                    }
                }
            }
        }

        let currentBranch: String
        if branchHead == "(detached)" {
            if !branchOID.isEmpty && branchOID != "(initial)" {
                currentBranch = "detached@\(branchOID.prefix(7))"
            } else {
                currentBranch = "HEAD"
            }
        } else if !branchHead.isEmpty {
            currentBranch = branchHead
        } else if !branchOID.isEmpty && branchOID != "(initial)" {
            currentBranch = String(branchOID.prefix(7))
        } else {
            currentBranch = "HEAD"
        }

        return BranchStatusInfo(
            currentBranch: currentBranch,
            aheadCount: aheadCount,
            behindCount: behindCount
        )
    }

    /// 解析 git status 输出
    private func parseStatusOutput(_ output: String) -> [GitFile] {
        var files: [GitFile] = []
        let lines = output.components(separatedBy: "\n")

        for line in lines where !line.isEmpty {
            if line.hasPrefix("1 ") {
                // 普通变更文件 (porcelain v2)
                let parts = line.components(separatedBy: " ")
                guard parts.count >= 9 else { continue }

                let xy = parts[1]
                let path = decodeGitPath(parts[8...].joined(separator: " "))

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
            } else if line.hasPrefix("2 ") {
                // 重命名/复制文件 (porcelain v2)
                let parts = line.components(separatedBy: " ")
                guard parts.count >= 10 else { continue }

                let xy = parts[1]
                let pathPart = parts[9...].joined(separator: " ")

                let newPath: String
                let oldPath: String?
                if let tabIndex = pathPart.firstIndex(of: "\t") {
                    newPath = decodeGitPath(String(pathPart[..<tabIndex]))
                    let after = pathPart.index(after: tabIndex)
                    let old = decodeGitPath(String(pathPart[after...]))
                    oldPath = old.isEmpty ? nil : old
                } else {
                    newPath = decodeGitPath(pathPart)
                    oldPath = nil
                }

                let indexStatus = String(xy.prefix(1))
                let workStatus = String(xy.suffix(1))

                if indexStatus != "." {
                    files.append(GitFile(
                        path: newPath,
                        status: parseFileStatus(indexStatus),
                        isStaged: true,
                        oldPath: oldPath
                    ))
                }

                if workStatus != "." {
                    files.append(GitFile(
                        path: newPath,
                        status: parseFileStatus(workStatus),
                        isStaged: false,
                        oldPath: oldPath
                    ))
                }
            } else if line.hasPrefix("? ") {
                // 未跟踪文件
                let path = decodeGitPath(String(line.dropFirst(2)))
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

    private func decodeGitPath(_ rawPath: String) -> String {
        let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.first == "\"", trimmed.last == "\"", trimmed.count >= 2 else {
            return trimmed
        }

        let inner = trimmed.dropFirst().dropLast()
        var data = Data()
        var index = inner.startIndex

        while index < inner.endIndex {
            let character = inner[index]

            if character == "\\" {
                let nextIndex = inner.index(after: index)
                guard nextIndex < inner.endIndex else {
                    data.append(contentsOf: String(character).utf8)
                    break
                }

                let escaped = inner[nextIndex]
                switch escaped {
                case "\\":
                    data.append(UInt8(ascii: "\\"))
                    index = inner.index(after: nextIndex)
                case "\"":
                    data.append(UInt8(ascii: "\""))
                    index = inner.index(after: nextIndex)
                case "t":
                    data.append(0x09)
                    index = inner.index(after: nextIndex)
                case "n":
                    data.append(0x0A)
                    index = inner.index(after: nextIndex)
                case "r":
                    data.append(0x0D)
                    index = inner.index(after: nextIndex)
                case "0"..."7":
                    var octal = String(escaped)
                    var cursor = inner.index(after: nextIndex)
                    var count = 1

                    while cursor < inner.endIndex, count < 3, isOctalDigit(inner[cursor]) {
                        octal.append(inner[cursor])
                        cursor = inner.index(after: cursor)
                        count += 1
                    }

                    if let byte = UInt8(octal, radix: 8) {
                        data.append(byte)
                    } else {
                        data.append(contentsOf: "\\\(octal)".utf8)
                    }
                    index = cursor
                default:
                    data.append(contentsOf: String(escaped).utf8)
                    index = inner.index(after: nextIndex)
                }
            } else {
                data.append(contentsOf: String(character).utf8)
                index = inner.index(after: index)
            }
        }

        return String(data: data, encoding: .utf8) ?? trimmed
    }

    private func isOctalDigit(_ character: Character) -> Bool {
        guard let scalar = character.unicodeScalars.first, character.unicodeScalars.count == 1 else {
            return false
        }
        return scalar.value >= 48 && scalar.value <= 55
    }

    // MARK: - 分支操作

    /// 获取所有分支
    func getBranches(in directory: String) async throws -> [GitBranch] {
        let output = try await runner.execute(
            ["branch", "-a", "--format=%(refname:short)|%(upstream:short)|%(HEAD)"],
            in: directory,
            timeout: 15.0
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
            ["add", "-A", "--"] + paths,
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

    /// 提交指定文件（会先将这些文件加入暂存区，仅提交这些文件）
    func commit(message: String, paths: [String], in directory: String) async throws {
        guard !paths.isEmpty else {
            try await commit(message: message, in: directory)
            return
        }
        _ = try await runner.execute(
            ["commit", "-m", message, "--"] + paths,
            in: directory
        )
    }

    // MARK: - 远程操作

    /// 拉取
    func pull(in directory: String) async throws -> PullSummary {
        let result = try await runner.run(
            ["-c", "core.quotepath=false", "pull", "--stat", "--no-progress"],
            in: directory,
            timeout: 90.0
        )

        guard result.isSuccess else {
            try throwCommandError(from: result)
        }

        let combinedOutput = [result.output, result.error]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n")

        return parsePullSummary(combinedOutput)
    }

    func getCurrentUpstream(in directory: String) async throws -> String {
        do {
            return try await runner.execute(
                ["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}"],
                in: directory,
                timeout: 15.0
            )
        } catch {
            if let gitError = error as? GitError,
               case .commandFailed = gitError {
                throw GitError.commandFailed(AppLocalization.shared.t(.noTrackingBranch))
            }
            throw error
        }
    }

    func forcePullOverwritingLocal(in directory: String) async throws {
        let upstream = try await getCurrentUpstream(in: directory)
        _ = try await runner.execute(
            ["fetch", "--all", "--prune"],
            in: directory,
            timeout: 90.0
        )
        _ = try await runner.execute(
            ["reset", "--hard", upstream],
            in: directory,
            timeout: 30.0
        )
        _ = try await runner.execute(
            ["clean", "-fd"],
            in: directory,
            timeout: 30.0
        )
    }

    /// 推送
    func push(in directory: String) async throws {
        _ = try await runner.execute(
            ["push"],
            in: directory,
            timeout: 90.0
        )
    }

    func forcePushOverwritingRemote(in directory: String) async throws {
        let upstream = try await getCurrentUpstream(in: directory)
        let components = upstream.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
        guard components.count == 2 else {
            throw GitError.commandFailed(AppLocalization.shared.t(.noTrackingBranch))
        }

        let remote = String(components[0])
        let remoteBranch = String(components[1])

        _ = try await runner.execute(
            ["push", "--force", remote, "HEAD:\(remoteBranch)"],
            in: directory,
            timeout: 90.0
        )
    }

    /// 获取远程更新
    func fetch(in directory: String) async throws {
        _ = try await runner.execute(
            ["fetch", "--all"],
            in: directory,
            timeout: 90.0
        )
    }

    private func throwCommandError(from result: CommandResult) throws -> Never {
        let error = result.error.lowercased()
        if error.contains("not a git repository") {
            throw GitError.notAGitRepository
        } else if error.contains("conflict") || error.contains("merge") {
            throw GitError.mergeConflict
        } else if error.contains("could not resolve host") || error.contains("network") {
            throw GitError.networkError(result.error)
        } else {
            throw GitError.commandFailed(result.error.isEmpty ? result.output : result.error)
        }
    }

    private func parsePullSummary(_ output: String) -> PullSummary {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return PullSummary(
                isAlreadyUpToDate: false,
                commitRange: nil,
                changedFilesCount: nil,
                insertions: nil,
                deletions: nil
            )
        }

        let lines = trimmed
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let isAlreadyUpToDate = lines.contains { $0 == "Already up to date." }

        var commitRange: String?
        var changedFilesCount: Int?
        var insertions: Int?
        var deletions: Int?

        for line in lines {
            if commitRange == nil,
               let range = firstRegexCapture(
                pattern: #"Updating ([0-9a-fA-F]+)\.\.([0-9a-fA-F]+)"#,
                in: line,
                joinWith: ".."
               ) {
                commitRange = range
            }

            if changedFilesCount == nil,
               let match = regexMatches(
                pattern: #"(\d+) files? changed(?:, (\d+) insertions?\(\+\))?(?:, (\d+) deletions?\(-\))?"#,
                in: line
               ) {
                changedFilesCount = Int(match[0])
                if match.count > 1, !match[1].isEmpty {
                    insertions = Int(match[1])
                }
                if match.count > 2, !match[2].isEmpty {
                    deletions = Int(match[2])
                }
            }
        }

        return PullSummary(
            isAlreadyUpToDate: isAlreadyUpToDate,
            commitRange: commitRange,
            changedFilesCount: changedFilesCount,
            insertions: insertions,
            deletions: deletions
        )
    }

    private func firstRegexCapture(pattern: String, in text: String, joinWith separator: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsrange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: nsrange),
              match.numberOfRanges >= 3,
              let firstRange = Range(match.range(at: 1), in: text),
              let secondRange = Range(match.range(at: 2), in: text) else {
            return nil
        }
        return "\(text[firstRange])\(separator)\(text[secondRange])"
    }

    private func regexMatches(pattern: String, in text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsrange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: nsrange), match.numberOfRanges > 1 else {
            return nil
        }

        return (1..<match.numberOfRanges).map { index in
            let range = match.range(at: index)
            guard range.location != NSNotFound, let swiftRange = Range(range, in: text) else {
                return ""
            }
            return String(text[swiftRange])
        }
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
            throw GitError.commandFailed(AppLocalization.shared.t(.commandCannotBeEmpty))
        }

        var gitArgs: [String]
        if firstArg.lowercased() == "git" {
            gitArgs = Array(args.dropFirst())
        } else {
            gitArgs = args
        }

        return try await runner.execute(gitArgs, in: directory)
    }

    /// 放弃指定文件的更改（还原到 HEAD）
    func discardChanges(_ paths: [String], in directory: String) async throws {
        guard !paths.isEmpty else { return }
        _ = try await runner.execute(
            ["restore", "--source=HEAD", "--worktree", "--"] + paths,
            in: directory
        )
    }

    /// 读取文件在 HEAD 的内容（文本）
    func showFileAtHEAD(path: String, in directory: String) async throws -> String {
        try await runner.execute(["show", "HEAD:\(path)"], in: directory)
    }
}
