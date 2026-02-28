import SwiftUI

struct ChangesTabView: View {
    @EnvironmentObject var localization: AppLocalization
    @ObservedObject var viewModel: RepositoryViewModel
    @State private var selectedPaths: Set<String> = []
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

    /// 暂存所选目标：仅对未暂存的变更（modified + untracked）生效
    private var stageSelectedTargets: [GitFile] {
        (modifiedFiles + untrackedFiles).filter { selectedPaths.contains($0.path) && $0.status != .conflicted }
    }

    private var allModifiedSelected: Bool {
        let modifiedPaths = Set(modifiedFiles.map(\.path))
        return !modifiedPaths.isEmpty && modifiedPaths.isSubset(of: selectedPaths)
    }

    /// 提交目标：有勾选则只提交勾选；未勾选则默认提交「已暂存 + 已修改」（不包含未跟踪）。
    private var commitTargetFiles: [GitFile] {
        let targets: [GitFile]
        if !selectedPaths.isEmpty {
            targets = (stagedFiles + modifiedFiles + untrackedFiles).filter { selectedPaths.contains($0.path) }
        } else {
            targets = stagedFiles + modifiedFiles
        }
        return targets.filter { $0.status != .conflicted }
    }

    private var allVisibleFiles: [GitFile] {
        stagedFiles + modifiedFiles + untrackedFiles
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
                    viewModel: viewModel,
                    stagedFiles: stagedFiles,
                    modifiedFiles: modifiedFiles,
                    untrackedFiles: untrackedFiles,
                    selectedPaths: $selectedPaths,
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
                            Label(localization.t(.stageAll), systemImage: "plus.circle")
                        }
                        .disabled(viewModel.unstageableFiles.isEmpty || viewModel.isOperating)

                        Button {
                            Task { await viewModel.stageModifiedOnly() }
                        } label: {
                            Label(localization.t(.stageModifiedOnly), systemImage: "checkmark.circle")
                        }
                        .disabled(modifiedFiles.isEmpty || viewModel.isOperating)

                        Button {
                            Task {
                                await viewModel.stageFiles(stageSelectedTargets)
                            }
                        } label: {
                            Label(localization.t(.stageSelected), systemImage: "plus")
                        }
                        .disabled(stageSelectedTargets.isEmpty || viewModel.isOperating)

                        Spacer()

                        Button {
                            Task { await viewModel.unstageAll() }
                        } label: {
                            Label(localization.t(.unstageAll), systemImage: "minus.circle")
                        }
                        .disabled(stagedFiles.isEmpty || viewModel.isOperating)
                    }
                    .buttonStyle(.bordered)

                    // 提交区域
                    VStack(alignment: .leading, spacing: 8) {
                        Text(localization.t(.commitMessage))
                            .font(.headline)

                        TextField(
                            "",
                            text: $commitMessage,
                            prompt: Text(localization.t(.enterCommitMessage))
                                .foregroundColor(.secondary),
                            axis: .vertical
                        )
                        .font(.system(.body, design: .monospaced))
                        .textFieldStyle(.plain)
                        .lineLimit(3...4)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(minHeight: 80, alignment: .topLeading)
                        .background(Color(NSColor.textBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )

                        HStack(spacing: 8) {
                            Button {
                                Task {
                                    await viewModel.stageCommitAndMaybePush(
                                        message: normalizedCommitMessage,
                                        files: commitTargetFiles,
                                        push: false
                                    )
                                    if viewModel.lastError == nil {
                                        commitMessage = ""
                                    }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text(localization.t(.commit))
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(
                                normalizedCommitMessage.isEmpty ||
                                commitTargetFiles.isEmpty ||
                                viewModel.isOperating
                            )

                            Button {
                                Task {
                                    await viewModel.stageCommitAndMaybePush(
                                        message: normalizedCommitMessage,
                                        files: commitTargetFiles,
                                        push: true
                                    )
                                    if viewModel.lastError == nil {
                                        commitMessage = ""
                                    }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "paperplane.fill")
                                    Text(localization.t(.commitAndPush))
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(
                                normalizedCommitMessage.isEmpty ||
                                commitTargetFiles.isEmpty ||
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
                    Text(localization.t(.selectFileToViewDiff))
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
            selectedPaths.subtract(modifiedPaths)
        } else {
            selectedPaths.formUnion(modifiedPaths)
        }
    }

    private func syncSelectionWithVisibleFiles() {
        let visiblePaths = Set(allVisibleFiles.map(\.path))
        selectedPaths.formIntersection(visiblePaths)
        if let currentDiffFile = selectedFileForDiff, !visiblePaths.contains(currentDiffFile.path) {
            selectedFileForDiff = nil
        }
    }
}
