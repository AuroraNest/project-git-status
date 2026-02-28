import SwiftUI

struct MainView: View {
    @EnvironmentObject var viewModel: MainViewModel
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var selectedRepository: GitRepository? {
        guard let id = viewModel.selectedRepositoryId else { return nil }
        return viewModel.getRepository(byId: id)
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selectedRepositoryId: $viewModel.selectedRepositoryId)
                .navigationSplitViewColumnWidth(min: 250, ideal: 280, max: 350)
        } detail: {
            if let repo = selectedRepository {
                RepositoryDetailView(repository: repo)
                    .id(repo.id)  // 强制在切换仓库时重建视图
            } else {
                EmptyStateView()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Task {
                        await viewModel.refreshAll()
                    }
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .help("刷新所有仓库状态")
                .disabled(viewModel.isLoading)

                Button {
                    viewModel.showAddProjectDialog()
                } label: {
                    Label("添加项目", systemImage: "plus.circle")
                }
                .help("添加项目目录")
            }
        }
        .sheet(isPresented: $viewModel.showingAddProject) {
            AddProjectSheet()
        }
        .alert("错误", isPresented: $viewModel.showingError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView("刷新中...")
                    .padding()
                    .background(.regularMaterial)
                    .cornerRadius(8)
            }
        }
    }
}

struct EmptyStateView: View {
    @EnvironmentObject var viewModel: MainViewModel

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.gearshape")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            if viewModel.projects.isEmpty {
                Text("还没有添加项目")
                    .font(.title2)
                    .foregroundColor(.secondary)
                Text("点击上方 + 按钮添加项目目录")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Button {
                    viewModel.showAddProjectDialog()
                } label: {
                    Label("添加项目", systemImage: "plus.circle")
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            } else {
                Text("选择一个仓库查看详情")
                    .font(.title2)
                    .foregroundColor(.secondary)
                Text("从左侧列表选择仓库")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
