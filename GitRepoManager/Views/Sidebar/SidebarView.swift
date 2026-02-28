import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var viewModel: MainViewModel
    @EnvironmentObject var localization: AppLocalization
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
                        ProjectRowView(projectId: project.id)
                    }
                    .contextMenu {
                        Button {
                            Task {
                                await viewModel.rescanAllProjects()
                            }
                        } label: {
                            Label(localization.t(.rescan), systemImage: "arrow.clockwise")
                        }

                        Divider()

                        Button(role: .destructive) {
                            viewModel.removeProject(project)
                        } label: {
                            Label(localization.t(.removeProject), systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle(localization.t(.gitRepositoryManager))
    }

    private func bindingForProject(_ project: Project) -> Binding<Bool> {
        Binding(
            get: { project.isExpanded },
            set: { viewModel.setProjectExpanded(project, isExpanded: $0) }
        )
    }
}
