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
                    Label(localization.t(.newBranch), systemImage: "plus.circle")
                }

                Button {
                    showMergeBranchSheet = true
                } label: {
                    Label(localization.t(.mergeBranch), systemImage: "arrow.triangle.merge")
                }
                .disabled(viewModel.localBranches.count < 2)

                Spacer()

                Button {
                    Task { await viewModel.fetchBranches() }
                } label: {
                    Label(localization.t(.fetchRemote), systemImage: "arrow.down.circle")
                }
                .disabled(viewModel.isLoading)
            }
            .buttonStyle(.bordered)
            .padding()

            Divider()

            // 分支列表
            List {
                // 本地分支
                Section(localization.t(.localBranches)) {
                    ForEach(viewModel.localBranches) { branch in
                        BranchRowView(branch: branch) {
                            Task { await viewModel.checkoutBranch(branch) }
                        }
                    }
                }

                // 远程分支
                if !viewModel.remoteBranches.isEmpty {
                    Section(localization.t(.remoteBranches)) {
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
                    Text(localization.t(.noBranchesFound))
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
    @EnvironmentObject var localization: AppLocalization
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
                    Text(localization.trackingBranch(tracking))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if !branch.isCurrent {
                Button(isRemote ? localization.t(.checkout) : localization.t(.switchBranch)) {
                    onCheckout()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Text(localization.t(.current))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct NewBranchSheet: View {
    @EnvironmentObject var localization: AppLocalization
    @Binding var branchName: String
    let onCreate: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text(localization.t(.newBranch))
                .font(.title2)
                .fontWeight(.semibold)

            TextField(localization.t(.branchName), text: $branchName)
                .textFieldStyle(.roundedBorder)

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
                .disabled(branchName.isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 300)
    }
}

struct MergeBranchSheet: View {
    @EnvironmentObject var localization: AppLocalization
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
                .disabled(selectedBranch == nil)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 350)
    }
}
