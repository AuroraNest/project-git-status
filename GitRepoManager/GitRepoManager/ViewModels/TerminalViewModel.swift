import SwiftUI

/// 终端输出行
struct TerminalLine: Identifiable {
    let id = UUID()
    let text: String
    let isCommand: Bool
    let isError: Bool

    init(text: String, isCommand: Bool = false, isError: Bool = false) {
        self.text = text
        self.isCommand = isCommand
        self.isError = isError
    }
}

@MainActor
class TerminalViewModel: ObservableObject {
    let repositoryPath: String

    @Published var outputLines: [TerminalLine] = []
    @Published var isExecuting = false
    @Published var commandHistory: [String] = []
    @Published var historyIndex: Int = -1

    private let gitService = GitService()

    init(repositoryPath: String) {
        self.repositoryPath = repositoryPath

        // 添加欢迎信息
        let repoName = URL(fileURLWithPath: repositoryPath).lastPathComponent
        outputLines.append(TerminalLine(text: "Git 终端 - \(repoName)"))
        outputLines.append(TerminalLine(text: "输入 git 命令执行操作（可省略 'git' 前缀）"))
        outputLines.append(TerminalLine(text: ""))
    }

    func executeCommand(_ command: String) async {
        guard !command.isEmpty else { return }

        // 添加到历史
        commandHistory.append(command)
        historyIndex = commandHistory.count

        // 添加命令行
        outputLines.append(TerminalLine(text: command, isCommand: true))

        isExecuting = true
        defer { isExecuting = false }

        do {
            let output = try await gitService.executeRawCommand(command, in: repositoryPath)

            // 添加输出
            if !output.isEmpty {
                for line in output.components(separatedBy: "\n") {
                    outputLines.append(TerminalLine(text: line))
                }
            }
        } catch {
            outputLines.append(TerminalLine(
                text: error.localizedDescription,
                isError: true
            ))
        }

        // 添加空行
        outputLines.append(TerminalLine(text: ""))
    }

    func clearOutput() {
        outputLines.removeAll()
        let repoName = URL(fileURLWithPath: repositoryPath).lastPathComponent
        outputLines.append(TerminalLine(text: "Git 终端 - \(repoName)"))
        outputLines.append(TerminalLine(text: ""))
    }

    func getPreviousCommand() -> String? {
        guard !commandHistory.isEmpty else { return nil }
        if historyIndex > 0 {
            historyIndex -= 1
        }
        return commandHistory[historyIndex]
    }

    func getNextCommand() -> String? {
        guard !commandHistory.isEmpty else { return nil }
        if historyIndex < commandHistory.count - 1 {
            historyIndex += 1
            return commandHistory[historyIndex]
        }
        historyIndex = commandHistory.count
        return ""
    }
}
