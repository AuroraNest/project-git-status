import Foundation

/// Git 命令执行结果
struct CommandResult {
    let output: String
    let error: String
    let exitCode: Int32

    var isSuccess: Bool {
        exitCode == 0
    }
}

/// Git 命令错误
enum GitError: LocalizedError {
    case commandFailed(String)
    case notAGitRepository
    case mergeConflict
    case detachedHead
    case networkError(String)
    case unknownError(String)

    var errorDescription: String? {
        let l10n = AppLocalization.shared
        switch self {
        case .commandFailed(let message):
            return l10n.gitCommandFailed(message)
        case .notAGitRepository:
            return l10n.t(.notAGitRepository)
        case .mergeConflict:
            return l10n.t(.mergeConflict)
        case .detachedHead:
            return l10n.t(.detachedHead)
        case .networkError(let message):
            return l10n.networkError(message)
        case .unknownError(let message):
            return l10n.unknownError(message)
        }
    }
}

/// Git 命令执行器
actor GitCommandRunner {
    private let gitPath: String

    init() {
        // 查找 git 路径
        self.gitPath = "/usr/bin/git"
    }

    private func defaultTimeout(for arguments: [String]) -> TimeInterval {
        guard let command = arguments.first?.lowercased() else {
            return 15.0
        }

        switch command {
        case "push", "pull", "fetch", "clone", "ls-remote", "submodule":
            return 90.0
        case "commit", "merge", "checkout", "switch", "restore", "reset":
            return 30.0
        case "status", "diff", "show", "branch", "rev-parse", "rev-list", "log":
            return 15.0
        default:
            return 20.0
        }
    }

    private func shellEscape(_ value: String) -> String {
        guard !value.isEmpty else { return "''" }
        let escaped = value.replacingOccurrences(of: "'", with: "'\\''")
        return "'\(escaped)'"
    }

    private func formattedCommand(_ arguments: [String]) -> String {
        (["git"] + arguments).map(shellEscape).joined(separator: " ")
    }

    /// 执行 Git 命令（带超时）
    func run(
        _ arguments: [String],
        in directory: String,
        environment: [String: String]? = nil,
        timeout: TimeInterval? = nil
    ) async throws -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: gitPath)
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: directory)
        let effectiveTimeout = timeout ?? defaultTimeout(for: arguments)

        var env = ProcessInfo.processInfo.environment
        env["LC_ALL"] = "en_US.UTF-8"
        env["LANG"] = "en_US.UTF-8"
        // GUI 场景下无法处理交互式凭证输入，直接禁用，避免 Git 在后台一直挂起。
        env["GIT_TERMINAL_PROMPT"] = "0"
        env["GCM_INTERACTIVE"] = "never"
        if let customEnv = environment {
            for (key, value) in customEnv {
                env[key] = value
            }
        }
        process.environment = env

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // 预先设置数据读取（避免阻塞）
        var outputData = Data()
        var errorData = Data()

        let outputHandle = outputPipe.fileHandleForReading
        let errorHandle = errorPipe.fileHandleForReading

        // 异步收集输出数据
        outputHandle.readabilityHandler = { handle in
            outputData.append(handle.availableData)
        }
        errorHandle.readabilityHandler = { handle in
            errorData.append(handle.availableData)
        }

        do {
            try process.run()

            // 超时处理
            let startTime = Date()
            while process.isRunning {
                if Date().timeIntervalSince(startTime) > effectiveTimeout {
                    process.terminate()
                    outputHandle.readabilityHandler = nil
                    errorHandle.readabilityHandler = nil
                    throw GitError.commandFailed(
                        AppLocalization.shared.gitCommandTimedOut(
                            command: formattedCommand(arguments),
                            timeoutSeconds: Int(effectiveTimeout.rounded()),
                            directory: directory
                        )
                    )
                }
                try await Task.sleep(nanoseconds: 50_000_000) // 50ms
            }

            // 等待最后的数据
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms

            // 清理 handlers
            outputHandle.readabilityHandler = nil
            errorHandle.readabilityHandler = nil

            let output = String(data: outputData, encoding: .utf8) ?? ""
            let error = String(data: errorData, encoding: .utf8) ?? ""

            return CommandResult(
                output: output.trimmingCharacters(in: .whitespacesAndNewlines),
                error: error.trimmingCharacters(in: .whitespacesAndNewlines),
                exitCode: process.terminationStatus
            )
        } catch let error as GitError {
            outputHandle.readabilityHandler = nil
            errorHandle.readabilityHandler = nil
            throw error
        } catch {
            outputHandle.readabilityHandler = nil
            errorHandle.readabilityHandler = nil
            throw GitError.unknownError(error.localizedDescription)
        }
    }

    /// 执行命令并检查结果
    func execute(
        _ arguments: [String],
        in directory: String,
        timeout: TimeInterval? = nil
    ) async throws -> String {
        let result = try await run(arguments, in: directory, timeout: timeout)

        if result.isSuccess {
            return result.output
        } else {
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
    }
}
