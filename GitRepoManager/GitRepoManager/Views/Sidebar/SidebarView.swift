import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var viewModel: MainViewModel
    @Binding var selectedRepositoryId: UUID?

    var body: some View {
        List(selection: $selectedRepositoryId) {
            ForEach(viewModel.projects) { project in
                Section {
                    DisclosureGroup(isExpanded: bindingForProject(project)) {
                        ForEach(project.repositories) { repo in
                            RepositoryRowView(repository: repo)
                                .tag(repo.id)
                        }
                    } label: {
                        ProjectRowView(project: project)
                    }
                    .contextMenu {
                        Button {
                            Task {
                                await viewModel.rescanAllProjects()
                            }
                        } label: {
                            Label("重新扫描", systemImage: "arrow.clockwise")
                        }

                        Divider()

                        Button(role: .destructive) {
                            viewModel.removeProject(project)
                        } label: {
                            Label("移除项目", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Git 仓库管理")
    }

    private func bindingForProject(_ project: Project) -> Binding<Bool> {
        Binding(
            get: { project.isExpanded },
            set: { viewModel.setProjectExpanded(project, isExpanded: $0) }
        )
    }
}

