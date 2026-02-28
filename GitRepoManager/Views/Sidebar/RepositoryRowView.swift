import SwiftUI

struct RepositoryRowView: View {
    let repository: GitRepository
    @EnvironmentObject var viewModel: MainViewModel

    var body: some View {
        HStack(spacing: 8) {
            // 仓库图标
            Image(systemName: "folder.fill.badge.gearshape")
                .foregroundColor(.green)

            VStack(alignment: .leading, spacing: 2) {
                // 仓库名称
                HStack(spacing: 4) {
                    Text(repository.name)
                        .font(.body)
                        .lineLimit(1)

                    // 显示相对路径（如果有）
                    if !repository.relativePath.isEmpty && repository.relativePath != repository.name {
                        Text("(\(repository.relativePath))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                // 分支名
                if let branch = repository.status?.currentBranch ?? repository.currentBranch {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.caption2)
                        Text(branch)
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            }

            Spacer()

            // 状态徽章
            if let status = repository.status {
                HStack(spacing: 6) {
                    if status.totalChangedCount > 0 {
                        StatusBadge(
                            count: status.totalChangedCount,
                            color: .orange,
                            icon: "pencil"
                        )
                    }

                    if status.aheadCount > 0 {
                        StatusBadge(
                            count: status.aheadCount,
                            color: .blue,
                            icon: "arrow.up"
                        )
                    }

                    if status.behindCount > 0 {
                        StatusBadge(
                            count: status.behindCount,
                            color: .purple,
                            icon: "arrow.down"
                        )
                    }
                }
            }

            // 错误指示
            if repository.lastError != nil {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .help(repository.lastError ?? "")
            }

            // 加载中
            if repository.isLoading {
                ProgressView()
                    .scaleEffect(0.6)
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button {
                viewModel.openInFinder(repository)
            } label: {
                Label("在 Finder 中显示", systemImage: "folder")
            }

            Button {
                viewModel.openInTerminal(repository)
            } label: {
                Label("在终端中打开", systemImage: "terminal")
            }

            Divider()

            Button {
                Task {
                    await viewModel.refreshRepository(repository)
                }
            } label: {
                Label("刷新状态", systemImage: "arrow.clockwise")
            }
        }
    }
}

