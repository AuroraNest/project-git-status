import SwiftUI

struct TerminalView: View {
    let repositoryPath: String
    @StateObject private var viewModel: TerminalViewModel
    @State private var commandInput: String = ""
    @FocusState private var isInputFocused: Bool

    init(repositoryPath: String) {
        self.repositoryPath = repositoryPath
        self._viewModel = StateObject(wrappedValue: TerminalViewModel(repositoryPath: repositoryPath))
    }

    var body: some View {
        VStack(spacing: 0) {
            // 输出区域
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(viewModel.outputLines) { line in
                            TerminalLineView(line: line)
                                .id(line.id)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color(NSColor.textBackgroundColor))
                .onChange(of: viewModel.outputLines.count) { _ in
                    if let lastLine = viewModel.outputLines.last {
                        withAnimation {
                            proxy.scrollTo(lastLine.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // 输入区域
            HStack(spacing: 8) {
                Text("$")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.accentColor)
                    .fontWeight(.bold)

                TextField("输入 git 命令...", text: $commandInput)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .focused($isInputFocused)
                    .onSubmit {
                        executeCommand()
                    }

                if viewModel.isExecuting {
                    ProgressView()
                        .scaleEffect(0.6)
                } else {
                    Button {
                        executeCommand()
                    } label: {
                        Image(systemName: "return")
                    }
                    .disabled(commandInput.isEmpty)
                    .keyboardShortcut(.return, modifiers: [])
                }

                Button {
                    viewModel.clearOutput()
                } label: {
                    Image(systemName: "trash")
                }
                .help("清空输出")
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .onAppear {
            isInputFocused = true
        }
    }

    private func executeCommand() {
        guard !commandInput.isEmpty else { return }
        let command = commandInput
        commandInput = ""
        Task {
            await viewModel.executeCommand(command)
        }
    }
}

struct TerminalLineView: View {
    let line: TerminalLine

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if line.isCommand {
                Text("$")
                    .foregroundColor(.accentColor)
                    .fontWeight(.bold)
            } else {
                Text(" ")
            }

            Text(line.text)
                .foregroundColor(line.isError ? .red : (line.isCommand ? .accentColor : .primary))
                .fontWeight(line.isCommand ? .medium : .regular)
        }
        .font(.system(.body, design: .monospaced))
        .textSelection(.enabled)
    }
}

