import SwiftUI

struct RepositoryDetailView: View {
    let repository: GitRepository
    @StateObject private var viewModel: RepositoryViewModel
    @State private var selectedTab: DetailTab = .changes

    enum DetailTab: String, CaseIterable {
        case changes = "变更"
        case branches = "分支"
        case terminal = "终端"
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
                    Text(tab.rawValue).tag(tab)
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
        .alert("操作失败", isPresented: .constant(viewModel.lastError != nil)) {
            Button("确定") {
                viewModel.clearMessages()
            }
        } message: {
            Text(viewModel.lastError ?? "")
        }
    }
}

struct RepositoryHeaderView: View {
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
                    Label("拉取", systemImage: "arrow.down.circle")
                }
                .disabled(viewModel.isOperating)
                .help("从远程拉取更新")

                Button {
                    Task { await viewModel.push() }
                } label: {
                    Label("推送", systemImage: "arrow.up.circle")
                }
                .disabled(viewModel.isOperating || (viewModel.status?.aheadCount ?? 0) == 0)
                .help("推送到远程")

                Button {
                    Task { await viewModel.loadStatus() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
                .help("刷新状态")
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

