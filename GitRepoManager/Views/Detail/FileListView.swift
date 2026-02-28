import SwiftUI

struct FileListView: View {
    @EnvironmentObject var localization: AppLocalization
    let stagedFiles: [GitFile]
    let modifiedFiles: [GitFile]
    let untrackedFiles: [GitFile]
    @Binding var selectedFiles: Set<GitFile>
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
                                isChecked: selectedFiles.contains(file),
                                onToggleCheck: { toggleSelection(file) },
                                onSelect: { selectedFileForDiff = file }
                            )
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
                                isChecked: selectedFiles.contains(file),
                                onToggleCheck: { toggleSelection(file) },
                                onSelect: { selectedFileForDiff = file }
                            )
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
                                isChecked: selectedFiles.contains(file),
                                onToggleCheck: { toggleSelection(file) },
                                onSelect: { selectedFileForDiff = file }
                            )
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
        if selectedFiles.contains(file) {
            selectedFiles.remove(file)
        } else {
            selectedFiles.insert(file)
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
