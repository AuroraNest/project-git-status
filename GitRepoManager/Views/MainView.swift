import SwiftUI

struct MainView: View {
    @EnvironmentObject var viewModel: MainViewModel
    @EnvironmentObject var localization: AppLocalization
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var selectedRepository: GitRepository? {
        guard let id = viewModel.selectedRepositoryId else { return nil }
        return viewModel.getRepository(byId: id)
    }

    private var selectedRepositoryBinding: Binding<UUID?> {
        Binding(
            get: { viewModel.selectedRepositoryId },
            set: { viewModel.setSelectedRepository($0) }
        )
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selectedRepositoryId: selectedRepositoryBinding)
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
                // 默认编辑器选择
                Menu {
                    ForEach(EditorType.installedEditors) { editor in
                        Button {
                            viewModel.preferredEditor = editor
                        } label: {
                            HStack {
                                Text(editor.displayName)
                                if viewModel.preferredEditor == editor {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Label(localization.t(.defaultEditor), systemImage: "hammer")
                }
                .help(localization.t(.defaultEditor))

                // 语言选择
                Menu {
                    ForEach(AppLanguage.allCases) { language in
                        Button {
                            localization.language = language
                        } label: {
                            HStack {
                                Text(language.optionLabel)
                                if localization.language == language {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Label(localization.language.optionLabel, systemImage: "globe")
                }
                .help(localization.t(.language))

                Button {
                    Task {
                        await viewModel.refreshAll()
                    }
                } label: {
                    Label(localization.t(.refresh), systemImage: "arrow.clockwise")
                }
                .help(localization.t(.refreshAllRepositories))
                .disabled(viewModel.isLoading)
                .keyboardShortcut("r", modifiers: .command)

                Button {
                    viewModel.showAddProjectDialog()
                } label: {
                    Label(localization.t(.addProject), systemImage: "plus.circle")
                }
                .help(localization.t(.addProjectDirectoryHelp))
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        .sheet(isPresented: $viewModel.showingAddProject) {
            AddProjectSheet()
        }
        .alert(localization.t(.error), isPresented: $viewModel.showingError) {
            Button(localization.t(.confirm), role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView(localization.t(.refreshing))
                    .padding()
                    .background(.regularMaterial)
                    .cornerRadius(8)
            }
        }
    }
}

struct EmptyStateView: View {
    @EnvironmentObject var viewModel: MainViewModel
    @EnvironmentObject var localization: AppLocalization

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.gearshape")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            if viewModel.projects.isEmpty {
                Text(localization.t(.noProjectsYet))
                    .font(.title2)
                    .foregroundColor(.secondary)
                Text(localization.t(.clickPlusToAddProjectDirectory))
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Button {
                    viewModel.showAddProjectDialog()
                } label: {
                    Label(localization.t(.addProject), systemImage: "plus.circle")
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            } else {
                Text(localization.t(.selectRepositoryToViewDetails))
                    .font(.title2)
                    .foregroundColor(.secondary)
                Text(localization.t(.selectRepositoryFromSidebar))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
