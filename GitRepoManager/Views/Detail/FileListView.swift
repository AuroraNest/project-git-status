import SwiftUI
import AppKit

struct FileListView: View {
    @EnvironmentObject var localization: AppLocalization
    @ObservedObject var viewModel: RepositoryViewModel
    let stagedFiles: [GitFile]
    let modifiedFiles: [GitFile]
    let untrackedFiles: [GitFile]
    @Binding var selectedPaths: Set<String>
    @Binding var selectedFileForDiff: GitFile?
    var allModifiedSelected: Bool = false
    var onToggleSelectAllModified: () -> Void = {}

    var hasNoChanges: Bool {
        stagedFiles.isEmpty && modifiedFiles.isEmpty && untrackedFiles.isEmpty
    }

    var body: some View {
        if hasNoChanges {
            VStack {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 48))
                    .foregroundColor(.green)
                Text(localization.t(.noFileChanges))
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                // 已暂存文件
                if !stagedFiles.isEmpty {
                    Section {
                        ForEach(stagedFiles) { file in
                            FileRowView(
                                file: file,
                                isSelected: selectedFileForDiff?.id == file.id,
                                isChecked: selectedPaths.contains(file.path),
                                onToggleCheck: { toggleSelection(file) },
                                onSelect: { selectedFileForDiff = file }
                            )
                            .contextMenu {
                                fileContextMenu(file)
                            }
                        }
                    } header: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(localization.t(.staged))
                            Spacer()
                            Text("\(stagedFiles.count)")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // 已修改文件
                if !modifiedFiles.isEmpty {
                    Section {
                        ForEach(modifiedFiles) { file in
                            FileRowView(
                                file: file,
                                isSelected: selectedFileForDiff?.id == file.id,
                                isChecked: selectedPaths.contains(file.path),
                                onToggleCheck: { toggleSelection(file) },
                                onSelect: { selectedFileForDiff = file }
                            )
                            .contextMenu {
                                fileContextMenu(file)
                            }
                        }
                    } header: {
                        HStack {
                            Image(systemName: "pencil.circle.fill")
                                .foregroundColor(.orange)
                            Text(localization.t(.modified))
                            Spacer()
                            Button(allModifiedSelected ? localization.t(.deselectAll) : localization.t(.selectAll)) {
                                onToggleSelectAllModified()
                            }
                            .buttonStyle(.plain)
                            .font(.caption)
                            .foregroundColor(.accentColor)
                            .disabled(viewModel.isRepoBusy)
                            Text("\(modifiedFiles.count)")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // 未跟踪文件
                if !untrackedFiles.isEmpty {
                    Section {
                        ForEach(untrackedFiles) { file in
                            FileRowView(
                                file: file,
                                isSelected: selectedFileForDiff?.id == file.id,
                                isChecked: selectedPaths.contains(file.path),
                                onToggleCheck: { toggleSelection(file) },
                                onSelect: { selectedFileForDiff = file }
                            )
                            .contextMenu {
                                fileContextMenu(file)
                            }
                        }
                    } header: {
                        HStack {
                            Image(systemName: "questionmark.circle.fill")
                                .foregroundColor(.gray)
                            Text(localization.t(.untracked))
                            Spacer()
                            Text("\(untrackedFiles.count)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .listStyle(.inset)
        }
    }

    private func toggleSelection(_ file: GitFile) {
        if selectedPaths.contains(file.path) {
            selectedPaths.remove(file.path)
        } else {
            selectedPaths.insert(file.path)
        }
    }

    @ViewBuilder
    private func fileContextMenu(_ file: GitFile) -> some View {
        Button(localization.t(.openChanges)) {
            selectedFileForDiff = file
        }

        Divider()

        Button(localization.t(.openFile)) {
            openWorkingFile(file)
        }
        .disabled(file.status == .deleted)

        Button(localization.t(.openFileHead)) {
            viewModel.openFileAtHEAD(file)
        }
        .disabled(viewModel.isRepoBusy || file.status == .untracked || file.status == .added)

        Divider()

        if file.isStaged {
            Button(viewModel.progressText(idle: .unstageChanges, progress: .unstageSelectedInProgress)) {
                Task { await viewModel.unstageFiles([file]) }
            }
            .disabled(viewModel.isRepoBusy)
        } else {
            Button(viewModel.progressText(idle: .stageChanges, progress: .stageSelectedInProgress)) {
                Task { await viewModel.stageFiles([file]) }
            }
            .disabled(viewModel.isRepoBusy)
        }

        Button(viewModel.progressText(idle: .discardChanges, progress: .discardChangesInProgress)) {
            Task { await viewModel.discardChanges(for: file) }
        }
        .disabled(viewModel.isRepoBusy || file.status == .untracked || file.status == .added)

        Button(viewModel.progressText(idle: .addToGitignore, progress: .addToGitignoreInProgress)) {
            Task { await viewModel.addToGitignore(path: file.path) }
        }
        .disabled(viewModel.isRepoBusy)

        Divider()

        Button(localization.t(.showInFinder)) {
            revealInFinder(file)
        }
    }

    private func workingFileURL(for file: GitFile) -> URL {
        URL(fileURLWithPath: viewModel.repository.path).appendingPathComponent(file.path)
    }

    private func openWorkingFile(_ file: GitFile) {
        let url = workingFileURL(for: file)
        guard FileManager.default.fileExists(atPath: url.path) else {
            viewModel.lastError = localization.fileNotFound(file.path)
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func revealInFinder(_ file: GitFile) {
        let url = workingFileURL(for: file)
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: viewModel.repository.path)
        }
    }
}

struct FileRowView: View {
    let file: GitFile
    var isSelected: Bool = false
    var isChecked: Bool = false
    var onToggleCheck: () -> Void = {}
    var onSelect: () -> Void = {}

    var body: some View {
        HStack(spacing: 8) {
            // 勾选框 - 点击勾选
            Button {
                onToggleCheck()
            } label: {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isChecked ? .accentColor : .secondary)
                    .font(.system(size: 18))
            }
            .buttonStyle(.plain)
            .frame(width: 24)

            // 状态图标
            Image(systemName: file.status.iconName)
                .foregroundColor(file.status.color)
                .frame(width: 16)

            // 文件信息 - 点击选中查看 diff
            VStack(alignment: .leading, spacing: 2) {
                Text(file.fileName)
                    .font(.body)
                    .lineLimit(1)

                if !file.directoryPath.isEmpty {
                    Text(file.directoryPath)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                onSelect()
            }

            // 状态标签
            Text(file.status.displayName)
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(file.status.color.opacity(0.15))
                .foregroundColor(file.status.color)
                .cornerRadius(4)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .cornerRadius(4)
    }
}
