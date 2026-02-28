import SwiftUI

struct ChangesTabView: View {
    @ObservedObject var viewModel: RepositoryViewModel
    @State private var selectedFiles: Set<GitFile> = []
    @State private var commitMessage: String = ""
    @State private var selectedFileForDiff: GitFile?

    private var stagedFiles: [GitFile] {
        viewModel.status?.stagedFiles ?? []
    }

    private var modifiedFiles: [GitFile] {
        viewModel.status?.modifiedFiles ?? []
    }

    private var untrackedFiles: [GitFile] {
        viewModel.status?.untrackedFiles ?? []
    }

    private var allVisibleFiles: [GitFile] {
        stagedFiles + modifiedFiles + untrackedFiles
    }

    private var selectedPaths: Set<String> {
        Set(selectedFiles.map(\.path))
    }

    private var allModifiedSelected: Bool {
        let modifiedPaths = Set(modifiedFiles.map(\.path))
        return !modifiedPaths.isEmpty && modifiedPaths.isSubset(of: selectedPaths)
    }

    private var normalizedCommitMessage: String {
        commitMessage.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        HSplitView {
            // 左侧：文件列表和操作
            VStack(spacing: 0) {
                // 文件列表
                FileListView(
                    stagedFiles: stagedFiles,
                    modifiedFiles: modifiedFiles,
                    untrackedFiles: untrackedFiles,
                    selectedFiles: $selectedFiles,
                    selectedFileForDiff: $selectedFileForDiff,
                    allModifiedSelected: allModifiedSelected,
                    onToggleSelectAllModified: toggleSelectAllModified
                )

                Divider()

                // 操作区域
                VStack(spacing: 12) {
                    // 暂存按钮
                    HStack {
                        Button {
                            Task { await viewModel.stageAll() }
                        } label: {
                            Label("暂存全部", systemImage: "plus.circle")
                        }
                        .disabled(viewModel.unstageableFiles.isEmpty || viewModel.isOperating)

                        Button {
                            Task { await viewModel.stageModifiedOnly() }
                        } label: {
                            Label("暂存已修改", systemImage: "checkmark.circle")
                        }
                        .disabled(modifiedFiles.isEmpty || viewModel.isOperating)

                        Button {
                            Task {
                                let filesToStage = Array(selectedFiles.filter { !$0.isStaged })
                                await viewModel.stageFiles(filesToStage)
                            }
                        } label: {
                            Label("暂存选中", systemImage: "plus")
                        }
                        .disabled(selectedFiles.filter { !$0.isStaged }.isEmpty || viewModel.isOperating)

                        Spacer()

                        Button {
                            Task { await viewModel.unstageAll() }
                        } label: {
                            Label("取消全部", systemImage: "minus.circle")
                        }
                        .disabled(stagedFiles.isEmpty || viewModel.isOperating)
                    }
                    .buttonStyle(.bordered)

                    // 提交区域
                    VStack(alignment: .leading, spacing: 8) {
                        Text("提交信息")
                            .font(.headline)

                        ZStack(alignment: .topLeading) {
                            if commitMessage.isEmpty {
                                Text("输入提交信息...")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 9)
                                    .padding(.top, 8)
                                    .allowsHitTesting(false)
                            }
                            TextEditor(text: $commitMessage)
                                .font(.system(.body, design: .monospaced))
                                .scrollContentBackground(.hidden)
                                .background(Color.clear)
                        }
                        .frame(height: 80)
                        .background(Color(NSColor.textBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )

                        HStack(spacing: 8) {
                            Button {
                                Task {
                                    await viewModel.commit(message: normalizedCommitMessage)
                                    if viewModel.lastError == nil {
                                        commitMessage = ""
                                    }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("提交")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(
                                normalizedCommitMessage.isEmpty ||
                                stagedFiles.isEmpty ||
                                viewModel.isOperating
                            )

                            Button {
                                Task {
                                    await viewModel.commitAndPush(message: normalizedCommitMessage)
                                    if viewModel.lastError == nil {
                                        commitMessage = ""
                                    }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "paperplane.fill")
                                    Text("提交并推送")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(
                                normalizedCommitMessage.isEmpty ||
                                stagedFiles.isEmpty ||
                                viewModel.isOperating
                            )
                        }
                    }
                }
                .padding()
            }
            .frame(minWidth: 300)

            // 右侧：Diff 预览
            if let file = selectedFileForDiff {
                DiffPreviewView(file: file, viewModel: viewModel)
            } else {
                VStack {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("选择文件查看差异")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onChange(of: allVisibleFiles.map(\.path)) { _ in
            syncSelectionWithVisibleFiles()
        }
    }

    private func toggleSelectAllModified() {
        let modifiedPaths = Set(modifiedFiles.map(\.path))
        if allModifiedSelected {
            selectedFiles = Set(selectedFiles.filter { !modifiedPaths.contains($0.path) })
        } else {
            let toAdd = modifiedFiles.filter { !selectedPaths.contains($0.path) }
            selectedFiles.formUnion(toAdd)
        }
    }

    private func syncSelectionWithVisibleFiles() {
        let visiblePaths = Set(allVisibleFiles.map(\.path))
        selectedFiles = Set(selectedFiles.filter { visiblePaths.contains($0.path) })
        if let currentDiffFile = selectedFileForDiff, !visiblePaths.contains(currentDiffFile.path) {
            selectedFileForDiff = nil
        }
    }
}
