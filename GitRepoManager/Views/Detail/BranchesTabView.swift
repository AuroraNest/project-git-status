import SwiftUI

struct BranchesTabView: View {
    @EnvironmentObject var localization: AppLocalization
    @ObservedObject var viewModel: RepositoryViewModel
    @State private var showNewBranchSheet = false
    @State private var showMergeBranchSheet = false
    @State private var newBranchName = ""

    var body: some View {
        VStack(spacing: 0) {
            // 操作按钮
            HStack {
                Button {
                    showNewBranchSheet = true
                } label: {
                    Label(
                        viewModel.progressText(idle: .newBranch, progress: .createBranchInProgress),
                        systemImage: "plus.circle"
                    )
                }
                .disabled(viewModel.isRepoBusy)

                Button {
                    showMergeBranchSheet = true
                } label: {
                    Label(
                        viewModel.progressText(idle: .mergeBranch, progress: .mergeBranchInProgress),
                        systemImage: "arrow.triangle.merge")
                }
                .disabled(viewModel.localBranches.count < 2 || viewModel.isRepoBusy)

                Spacer()

                Button {
                    Task { await viewModel.fetchBranches() }
                } label: {
                    Label(
                        viewModel.progressText(idle: .fetchRemote, progress: .fetchRemoteInProgress),
                        systemImage: "arrow.down.circle"
                    )
                }
                .disabled(viewModel.isRepoBusy)
            }
            .buttonStyle(.bordered)
            .padding()

            Divider()

            // 三栏布局：分支 | 提交历史 | 提交详情
            HSplitView {
                // 左边：分支列表
                BranchListView(viewModel: viewModel)
                    .frame(minWidth: 180, idealWidth: 220)

                // 中间：提交历史
                CommitHistoryView(viewModel: viewModel)
                    .frame(minWidth: 280, idealWidth: 350)

                // 右边：提交详情
                CommitDetailView(viewModel: viewModel)
                    .frame(minWidth: 300, idealWidth: 400)
            }
        }
        .sheet(isPresented: $showNewBranchSheet) {
            NewBranchSheet(branchName: $newBranchName, isBusy: viewModel.isRepoBusy) {
                Task {
                    await viewModel.createBranch(name: newBranchName)
                    newBranchName = ""
                    showNewBranchSheet = false
                }
            }
        }
        .sheet(isPresented: $showMergeBranchSheet) {
            MergeBranchSheet(
                branches: viewModel.localBranches,
                currentBranch: viewModel.status?.currentBranch ?? "",
                isBusy: viewModel.isRepoBusy
            ) { branch in
                Task {
                    await viewModel.mergeBranch(branch)
                    showMergeBranchSheet = false
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.loadCommitHistory(reset: true)
            }
        }
    }
}

// MARK: - 分支列表视图

struct BranchListView: View {
    @EnvironmentObject var localization: AppLocalization
    @ObservedObject var viewModel: RepositoryViewModel

    var body: some View {
        List {
            // 本地分支
            Section(localization.t(.localBranches)) {
                ForEach(viewModel.localBranches) { branch in
                    BranchRowView(
                        branch: branch,
                        actionsDisabled: viewModel.isRepoBusy,
                        actionTitle: viewModel.progressText(idle: .switchBranch, progress: .switchBranchInProgress)
                    ) {
                        Task { await viewModel.checkoutBranch(branch) }
                    }
                }
            }

            // 远程分支
            if !viewModel.remoteBranches.isEmpty {
                Section(localization.t(.remoteBranches)) {
                    ForEach(viewModel.remoteBranches) { branch in
                        BranchRowView(
                            branch: branch,
                            isRemote: true,
                            actionsDisabled: viewModel.isRepoBusy,
                            actionTitle: viewModel.progressText(idle: .checkout, progress: .switchBranchInProgress)
                        ) {
                            Task { await viewModel.checkoutRemoteBranch(branch) }
                        }
                    }
                }
            }
        }
        .listStyle(.inset)
        .overlay {
            if viewModel.branches.isEmpty && !viewModel.isLoading {
                VStack {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text(localization.t(.noBranchesFound))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if viewModel.isLoading {
                ProgressView()
            }
        }
    }
}

// MARK: - 提交历史视图

struct CommitHistoryView: View {
    @EnvironmentObject var localization: AppLocalization
    @ObservedObject var viewModel: RepositoryViewModel

    var body: some View {
        VStack(spacing: 0) {
            // 标题
            HStack {
                Label(localization.t(.commitHistory), systemImage: "clock.arrow.circlepath")
                    .font(.headline)
                Spacer()

                if viewModel.isLoadingCommits {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // 提交列表
            if viewModel.commits.isEmpty && !viewModel.isLoadingCommits {
                VStack {
                    Image(systemName: "clock")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text(localization.t(.noCommitHistory))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.commits) { commit in
                            CommitRowView(
                                commit: commit,
                                isSelected: viewModel.selectedCommit?.id == commit.id
                            )
                            .environmentObject(viewModel)
                            .onTapGesture {
                                Task {
                                    await viewModel.selectCommit(commit)
                                }
                            }

                            Divider()
                                .padding(.leading, 68)
                        }

                        // 加载更多
                        if viewModel.hasMoreCommits {
                            Button {
                                Task {
                                    await viewModel.loadCommitHistory()
                                }
                            } label: {
                                if viewModel.isLoadingCommits {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Text(localization.t(.loadMore))
                                }
                            }
                            .buttonStyle(.bordered)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .onAppear {
                                // 滚动到底部时自动加载
                                Task {
                                    await viewModel.loadCommitHistory()
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

// MARK: - 提交详情视图

struct CommitDetailView: View {
    @EnvironmentObject var localization: AppLocalization
    @ObservedObject var viewModel: RepositoryViewModel

    var body: some View {
        VStack(spacing: 0) {
            // 标题
            HStack {
                Label(localization.t(.commitDetails), systemImage: "doc.text.magnifyingglass")
                    .font(.headline)
                Spacer()

                if viewModel.isLoadingCommitDetail {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            if let detail = viewModel.selectedCommitDetail {
                // 提交信息
                VStack(alignment: .leading, spacing: 8) {
                    // Hash
                    HStack {
                        Text("Hash:")
                            .foregroundColor(.secondary)
                        Text(detail.fullHash.prefix(12))
                            .font(.system(.body, design: .monospaced))
                        Spacer()
                    }

                    // 标题
                    Text(detail.subject)
                        .font(.headline)
                        .lineLimit(2)

                    // 正文（如果有）
                    if !detail.body.isEmpty {
                        Text(detail.body)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }

                    // 作者和时间
                    HStack {
                        Text(detail.author)
                        Text("·")
                        Text(detail.relativeDate)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)

                    // 统计
                    if !detail.stats.isEmpty {
                        Text(detail.stats)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

                Divider()

                // 变更文件列表
                HSplitView {
                    // 文件列表
                    List(detail.files, selection: Binding(
                        get: { viewModel.selectedCommitFile },
                        set: { file in
                            Task { await viewModel.selectCommitFile(file) }
                        }
                    )) { file in
                        HStack(spacing: 6) {
                            Image(systemName: file.statusIcon)
                                .foregroundColor(colorForStatus(file.status))
                                .frame(width: 16)

                            Text(file.fileName)
                                .lineLimit(1)

                            Spacer()
                        }
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            Task { await viewModel.selectCommitFile(file) }
                        }
                        .background(
                            viewModel.selectedCommitFile?.path == file.path
                                ? Color.accentColor.opacity(0.2)
                                : Color.clear
                        )
                        .cornerRadius(4)
                    }
                    .listStyle(.plain)
                    .frame(minWidth: 150, idealWidth: 180)

                    // Diff 预览
                    VStack(spacing: 0) {
                        if viewModel.isLoadingFileDiff {
                            ProgressView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else if let diff = viewModel.selectedCommitFileDiff {
                            ScrollView([.horizontal, .vertical]) {
                                Text(diff)
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        } else {
                            VStack {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 32))
                                    .foregroundColor(.secondary)
                                Text(localization.t(.selectFileToViewDiff))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
            } else if viewModel.selectedCommit != nil {
                // 正在加载
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 未选择提交
                VStack {
                    Image(systemName: "arrow.left.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text(localization.t(.selectCommitToViewDetails))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func colorForStatus(_ status: CommitFileStatus) -> Color {
        switch status {
        case .added: return .green
        case .modified: return .orange
        case .deleted: return .red
        case .renamed: return .blue
        case .copied: return .purple
        }
    }
}

// MARK: - 分支行视图

struct BranchRowView: View {
    @EnvironmentObject var localization: AppLocalization
    let branch: GitBranch
    var isRemote: Bool = false
    var actionsDisabled: Bool = false
    var actionTitle: String? = nil
    let onCheckout: () -> Void

    var body: some View {
        HStack {
            if branch.isCurrent {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Image(systemName: isRemote ? "cloud" : "arrow.triangle.branch")
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading) {
                Text(branch.displayName)
                    .fontWeight(branch.isCurrent ? .semibold : .regular)

                if let tracking = branch.trackingBranch {
                    Text(localization.trackingBranch(tracking))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if !branch.isCurrent {
                Button(actionTitle ?? (isRemote ? localization.t(.checkout) : localization.t(.switchBranch))) {
                    onCheckout()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(actionsDisabled)
            } else {
                Text(localization.t(.current))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 新建分支弹窗

struct NewBranchSheet: View {
    @EnvironmentObject var localization: AppLocalization
    @Binding var branchName: String
    var isBusy: Bool = false
    let onCreate: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text(localization.t(.newBranch))
                .font(.title2)
                .fontWeight(.semibold)

            TextField(localization.t(.branchName), text: $branchName)
                .textFieldStyle(.roundedBorder)
                .disabled(isBusy)

            HStack {
                Button(localization.t(.cancel)) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(localization.t(.create)) {
                    onCreate()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(branchName.isEmpty || isBusy)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 300)
    }
}

// MARK: - 合并分支弹窗

struct MergeBranchSheet: View {
    @EnvironmentObject var localization: AppLocalization
    let branches: [GitBranch]
    let currentBranch: String
    var isBusy: Bool = false
    let onMerge: (GitBranch) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedBranch: GitBranch?

    var availableBranches: [GitBranch] {
        branches.filter { !$0.isCurrent }
    }

    var body: some View {
        VStack(spacing: 20) {
            Text(localization.t(.mergeBranch))
                .font(.title2)
                .fontWeight(.semibold)

            Text(localization.mergeSelectedBranchInto(currentBranch))
                .font(.subheadline)
                .foregroundColor(.secondary)

            Picker(localization.t(.selectBranch), selection: $selectedBranch) {
                Text(localization.t(.pleaseChoose)).tag(nil as GitBranch?)
                ForEach(availableBranches) { branch in
                    Text(branch.name).tag(branch as GitBranch?)
                }
            }
            .pickerStyle(.menu)
            .disabled(isBusy)

            HStack {
                Button(localization.t(.cancel)) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(localization.t(.merge)) {
                    if let branch = selectedBranch {
                        onMerge(branch)
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedBranch == nil || isBusy)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 350)
    }
}
