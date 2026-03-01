import AppKit
import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var viewModel: MainViewModel
    @EnvironmentObject var localization: AppLocalization
    @Binding var selectedRepositoryId: UUID?
    @State private var editingProject: Project?
    @State private var draggingProjectId: UUID?

    var body: some View {
        List(selection: $selectedRepositoryId) {
            if !viewModel.pinnedProjects.isEmpty {
                Section {
                    ForEach(viewModel.pinnedProjects) { project in
                        projectDisclosureGroup(project)
                    }
                } header: {
                    Text(localization.t(.pinnedProjects))
                }
            }

            if !viewModel.regularProjects.isEmpty {
                Section {
                    ForEach(viewModel.regularProjects) { project in
                        projectDisclosureGroup(project)
                    }
                } header: {
                    Text(localization.t(.otherProjects))
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle(localization.t(.gitRepositoryManager))
        .sheet(item: $editingProject) { project in
            ProjectNoteSheet(project: project) { note in
                viewModel.updateProjectNote(project, note: note)
            }
        }
    }

    private func bindingForProject(_ project: Project) -> Binding<Bool> {
        Binding(
            get: {
                viewModel.projects.first(where: { $0.id == project.id })?.isExpanded ?? project.isExpanded
            },
            set: { viewModel.setProjectExpanded(project, isExpanded: $0) }
        )
    }

    @ViewBuilder
    private func projectDisclosureGroup(_ project: Project) -> some View {
        let isExpanded = bindingForProject(project).wrappedValue

        ProjectRowView(
            projectId: project.id,
            isSelected: viewModel.selectedProjectId == project.id,
            isExpanded: isExpanded,
            toggleExpand: {
                viewModel.toggleProjectExpanded(project)
            }
        )
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.setSelectedProject(project.id)
        }
        .onTapGesture(count: 2) {
            viewModel.setSelectedProject(project.id)
            viewModel.toggleProjectExpanded(project)
        }
        .onDrag {
            draggingProjectId = project.id
            return NSItemProvider(object: project.id.uuidString as NSString)
        }
        .dropDestination(for: String.self) { items, _ in
            let draggedId = draggingProjectId ?? items.compactMap(UUID.init(uuidString:)).first
            guard let draggedId else { return false }
            viewModel.moveProject(draggedProjectId: draggedId, before: project.id)
            draggingProjectId = nil
            return true
        }
        .contextMenu {
            Button {
                Task {
                    await viewModel.rescanProject(project)
                }
            } label: {
                Label(localization.t(.rescan), systemImage: "arrow.clockwise")
            }

            Button {
                viewModel.setProjectPinned(project, isPinned: !project.isPinned)
            } label: {
                Label(
                    localization.t(project.isPinned ? .unpinProject : .pinProject),
                    systemImage: project.isPinned ? "pin.slash" : "pin"
                )
            }

            Button {
                editingProject = project
            } label: {
                Label(localization.t(.editProjectNote), systemImage: "note.text")
            }

            Divider()

            Button(role: .destructive) {
                viewModel.removeProject(project)
            } label: {
                Label(localization.t(.removeProject), systemImage: "trash")
            }
        }

        if isExpanded {
            ForEach(project.repositories) { repo in
                RepositoryRowView(repository: repo)
                    .tag(repo.id)
                    .padding(.leading, 46)
            }
        }
    }
}

struct ProjectNoteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var localization: AppLocalization

    let project: Project
    let onSave: (String) -> Void

    @State private var note: String

    init(project: Project, onSave: @escaping (String) -> Void) {
        self.project = project
        self.onSave = onSave
        _note = State(initialValue: project.note)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(project.name)
                .font(.headline)

            Text(localization.t(.projectNote))
                .font(.subheadline)
                .foregroundColor(.secondary)

            TextField(
                "",
                text: $note,
                prompt: Text(localization.t(.notePlaceholder)).foregroundColor(.secondary),
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .lineLimit(3...5)
            .padding(10)
            .frame(minHeight: 96, alignment: .topLeading)
            .background(Color(NSColor.textBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
            )

            HStack {
                Spacer()

                Button(localization.t(.cancel)) {
                    dismiss()
                }

                Button(localization.t(.save)) {
                    onSave(note)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(width: 420)
    }
}
