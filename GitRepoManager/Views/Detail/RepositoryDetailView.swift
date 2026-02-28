import SwiftUI

struct RepositoryDetailView: View {
    @EnvironmentObject var localization: AppLocalization
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
        // 操作提示
        .overlay(alignment: .bottom) {
            if let message = viewModel.operationMessage {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(message)
                }
                .padding()
                .background(.regularMaterial)
                .cornerRadius(8)
                .padding()
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
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
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}
