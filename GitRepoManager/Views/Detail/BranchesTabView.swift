import SwiftUI

struct BranchesTabView: View {
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
                    Label("新建分支", systemImage: "plus.circle")
                }

                Button {
                    showMergeBranchSheet = true
                } label: {
                    Label("合并分支", systemImage: "arrow.triangle.merge")
                }
                .disabled(viewModel.localBranches.count < 2)

                Spacer()

                Button {
                    Task { await viewModel.fetchBranches() }
                } label: {
                    Label("获取远程", systemImage: "arrow.down.circle")
                }
                .disabled(viewModel.isLoading)
            }
            .buttonStyle(.bordered)
            .padding()

            Divider()

            // 分支列表
            List {
                // 本地分支
                Section("本地分支") {
                    ForEach(viewModel.localBranches) { branch in
                        BranchRowView(branch: branch) {
                            Task { await viewModel.checkoutBranch(branch) }
                        }
                    }
                }

                // 远程分支
                if !viewModel.remoteBranches.isEmpty {
                    Section("远程分支") {
                        ForEach(viewModel.remoteBranches) { branch in
                            BranchRowView(branch: branch, isRemote: true) {
                                Task { await viewModel.checkoutRemoteBranch(branch) }
                            }
                        }
                    }
                }
            }
            .listStyle(.inset)

            if viewModel.branches.isEmpty && !viewModel.isLoading {
                VStack {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("没有找到分支")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showNewBranchSheet) {
            NewBranchSheet(branchName: $newBranchName) {
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
                currentBranch: viewModel.status?.currentBranch ?? ""
            ) { branch in
                Task {
                    await viewModel.mergeBranch(branch)
                    showMergeBranchSheet = false
                }
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
    }
}

struct BranchRowView: View {
    let branch: GitBranch
    var isRemote: Bool = false
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
                    Text("跟踪: \(tracking)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if !branch.isCurrent {
                Button(isRemote ? "检出" : "切换") {
                    onCheckout()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Text("当前")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct NewBranchSheet: View {
    @Binding var branchName: String
    let onCreate: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("新建分支")
                .font(.title2)
                .fontWeight(.semibold)

            TextField("分支名称", text: $branchName)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("创建") {
                    onCreate()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(branchName.isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 300)
    }
}

struct MergeBranchSheet: View {
    let branches: [GitBranch]
    let currentBranch: String
    let onMerge: (GitBranch) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedBranch: GitBranch?

    var availableBranches: [GitBranch] {
        branches.filter { !$0.isCurrent }
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("合并分支")
                .font(.title2)
                .fontWeight(.semibold)

            Text("将选择的分支合并到 \(currentBranch)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Picker("选择分支", selection: $selectedBranch) {
                Text("请选择...").tag(nil as GitBranch?)
                ForEach(availableBranches) { branch in
                    Text(branch.name).tag(branch as GitBranch?)
                }
            }
            .pickerStyle(.menu)

            HStack {
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("合并") {
                    if let branch = selectedBranch {
                        onMerge(branch)
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedBranch == nil)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 350)
    }
}

