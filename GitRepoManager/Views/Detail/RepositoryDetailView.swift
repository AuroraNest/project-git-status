import SwiftUI

struct RepositoryDetailView: View {
    @EnvironmentObject var localization: AppLocalization
    @EnvironmentObject var mainViewModel: MainViewModel
    let repository: GitRepository
    @StateObject private var viewModel: RepositoryViewModel
    @State private var selectedTab: DetailTab = .changes

    enum DetailTab: CaseIterable {
        case changes
        case branches
        case terminal
    }

    init(repository: GitRepository) {
        self.repository = repository
        self._viewModel = StateObject(wrappedValue: RepositoryViewModel(repository: repository))
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部信息栏
            RepositoryHeaderView(repository: repository, viewModel: viewModel)

            Divider()

            // 标签页选择
            Picker("", selection: $selectedTab) {
                ForEach(DetailTab.allCases, id: \.self) { tab in
                    Text(title(for: tab)).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            // 内容区域
            switch selectedTab {
            case .changes:
                ChangesTabView(viewModel: viewModel)
            case .branches:
                BranchesTabView(viewModel: viewModel)
            case .terminal:
                TerminalView(repositoryPath: repository.path)
            }
        }
        .navigationTitle(repository.name)
        .task {
            await viewModel.loadStatus()
        }
        // 同步到侧边栏/菜单栏，避免“提交/推送后状态不更新”
        .onChange(of: viewModel.status) { newStatus in
            mainViewModel.syncRepositoryRuntimeState(
                projectId: repository.parentProjectId,
                repoId: repository.id,
                status: newStatus,
                lastError: viewModel.lastError
            )
        }
        .onChange(of: viewModel.lastError) { newError in
            mainViewModel.syncRepositoryRuntimeState(
                projectId: repository.parentProjectId,
                repoId: repository.id,
                status: viewModel.status,
                lastError: newError
            )
        }
        // 操作提示
        .overlay(alignment: .bottom) {
            if let message = viewModel.operationMessage {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(message)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .background(.regularMaterial)
                .cornerRadius(8)
                .padding()
                .frame(maxWidth: 520)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onAppear {
                    let dismissDelay = message.count > 24 ? 4.0 : 2.0
                    DispatchQueue.main.asyncAfter(deadline: .now() + dismissDelay) {
                        withAnimation {
                            viewModel.clearMessages()
                        }
                    }
                }
            }
        }
        // 错误提示
        .alert(localization.t(.operationFailed), isPresented: .constant(viewModel.lastError != nil)) {
            Button(localization.t(.confirm)) {
                viewModel.clearMessages()
            }
        } message: {
            Text(viewModel.lastError ?? "")
        }
    }

    private func title(for tab: DetailTab) -> String {
        switch tab {
        case .changes:
            return localization.t(.changes)
        case .branches:
            return localization.t(.branches)
        case .terminal:
            return localization.t(.terminal)
        }
    }
}

struct RepositoryHeaderView: View {
    @EnvironmentObject var localization: AppLocalization
    let repository: GitRepository
    @ObservedObject var viewModel: RepositoryViewModel
    @State private var stagedDangerAction: DangerAction?
    @State private var finalDangerAction: DangerAction?

    private enum DangerAction: String, Identifiable {
        case forcePullOverwriteLocal
        case forcePushOverwriteRemote

        var id: String { rawValue }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(repository.name)
                        .font(.title2)
                        .fontWeight(.semibold)

                    if let branch = viewModel.status?.currentBranch {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.branch")
                            Text(branch)
                        }
                        .font(.subheadline)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(4)
                    }
                }

                Text(repository.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // 快速操作按钮
            HStack(spacing: 12) {
                Button {
                    Task { await viewModel.sync() }
                } label: {
                    Label(localization.t(.sync), systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(viewModel.isOperating)
                .help(localization.t(.syncHelp))

                Button {
                    Task { await viewModel.pull() }
                } label: {
                    Label(localization.t(.pull), systemImage: "arrow.down.circle")
                }
                .disabled(viewModel.isOperating)
                .help(localization.t(.pullHelp))

                Button {
                    Task { await viewModel.push() }
                } label: {
                    Label(localization.t(.push), systemImage: "arrow.up.circle")
                }
                .disabled(viewModel.isOperating || (viewModel.status?.aheadCount ?? 0) == 0)
                .help(localization.t(.pushHelp))

                Button {
                    Task { await viewModel.loadStatus() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
                .help(localization.t(.refreshStatus))

                Menu {
                    Button(role: .destructive) {
                        stagedDangerAction = .forcePullOverwriteLocal
                    } label: {
                        Label(localization.t(.forcePullOverwriteLocal), systemImage: "arrow.down.circle.fill")
                    }

                    Button(role: .destructive) {
                        stagedDangerAction = .forcePushOverwriteRemote
                    } label: {
                        Label(localization.t(.forcePushOverwriteRemote), systemImage: "arrow.up.circle.fill")
                    }
                } label: {
                    Label(localization.t(.dangerActions), systemImage: "exclamationmark.triangle")
                }
                .tint(.orange)
                .disabled(viewModel.isLoading || viewModel.isOperating)
                .help(localization.t(.dangerActionsHelp))
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .confirmationDialog(
            localization.t(.dangerActions),
            isPresented: dangerDialogBinding,
            titleVisibility: .visible
        ) {
            Button(localization.t(.continueConfirm), role: .destructive) {
                finalDangerAction = stagedDangerAction
                stagedDangerAction = nil
            }
            Button(localization.t(.cancel), role: .cancel) {
                stagedDangerAction = nil
            }
        } message: {
            Text(firstConfirmationMessage)
        }
        .alert(
            finalConfirmationTitle,
            isPresented: finalDangerAlertBinding
        ) {
            Button(localization.t(.finalConfirm), role: .destructive) {
                let action = finalDangerAction
                finalDangerAction = nil
                runDangerAction(action)
            }
            Button(localization.t(.cancel), role: .cancel) {
                finalDangerAction = nil
            }
        } message: {
            Text(finalConfirmationMessage)
        }
    }

    private var currentBranch: String {
        viewModel.status?.currentBranch ?? repository.status?.currentBranch ?? "HEAD"
    }

    private var dangerDialogBinding: Binding<Bool> {
        Binding(
            get: { stagedDangerAction != nil },
            set: { newValue in
                if !newValue {
                    stagedDangerAction = nil
                }
            }
        )
    }

    private var finalDangerAlertBinding: Binding<Bool> {
        Binding(
            get: { finalDangerAction != nil },
            set: { newValue in
                if !newValue {
                    finalDangerAction = nil
                }
            }
        )
    }

    private var firstConfirmationMessage: String {
        guard let action = stagedDangerAction else { return "" }

        switch action {
        case .forcePullOverwriteLocal:
            return localization.forcePullOverwriteLocalFirstConfirm(
                repoName: repository.name,
                branch: currentBranch
            )
        case .forcePushOverwriteRemote:
            return localization.forcePushOverwriteRemoteFirstConfirm(
                repoName: repository.name,
                branch: currentBranch
            )
        }
    }

    private var finalConfirmationTitle: String {
        guard let action = finalDangerAction else { return localization.t(.dangerActions) }

        switch action {
        case .forcePullOverwriteLocal:
            return localization.t(.forcePullOverwriteLocal)
        case .forcePushOverwriteRemote:
            return localization.t(.forcePushOverwriteRemote)
        }
    }

    private var finalConfirmationMessage: String {
        guard let action = finalDangerAction else { return "" }

        switch action {
        case .forcePullOverwriteLocal:
            return localization.forcePullOverwriteLocalFinalConfirm(
                repoName: repository.name,
                branch: currentBranch
            )
        case .forcePushOverwriteRemote:
            return localization.forcePushOverwriteRemoteFinalConfirm(
                repoName: repository.name,
                branch: currentBranch
            )
        }
    }

    private func runDangerAction(_ action: DangerAction?) {
        guard let action else { return }

        Task {
            switch action {
            case .forcePullOverwriteLocal:
                await viewModel.forcePullOverwritingLocal()
            case .forcePushOverwriteRemote:
                await viewModel.forcePushOverwritingRemote()
            }
        }
    }
}
