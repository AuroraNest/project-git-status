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

    /// 执行 Git 命令（带超时）
    func run(
        _ arguments: [String],
        in directory: String,
        environment: [String: String]? = nil,
        timeout: TimeInterval = 5.0
    ) async throws -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: gitPath)
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: directory)

        var env = ProcessInfo.processInfo.environment
        env["LC_ALL"] = "en_US.UTF-8"
        env["LANG"] = "en_US.UTF-8"
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
                if Date().timeIntervalSince(startTime) > timeout {
                    process.terminate()
                    outputHandle.readabilityHandler = nil
                    errorHandle.readabilityHandler = nil
                    throw GitError.commandFailed(AppLocalization.shared.t(.commandTimeout))
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
        timeout: TimeInterval = 5.0
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
