import SwiftUI

struct ProjectRowView: View {
    let projectId: UUID
    let isSelected: Bool
    let isExpanded: Bool
    let toggleExpand: () -> Void
    @EnvironmentObject var viewModel: MainViewModel
    @EnvironmentObject var localization: AppLocalization

    private var project: Project? {
        viewModel.projects.first(where: { $0.id == projectId })
    }

    var totalChanges: Int {
        (project?.repositories ?? []).reduce(0) { sum, repo in
            sum + (repo.status?.totalChangedCount ?? 0)
        }
    }

    var totalUnpushed: Int {
        (project?.repositories ?? []).reduce(0) { sum, repo in
            sum + (repo.status?.aheadCount ?? 0)
        }
    }

    var body: some View {
        let projectName = project?.name ?? ""
        let repositoryCount = project?.repositories.count ?? 0
        let projectNote = project?.note ?? ""
        let isPinned = project?.isPinned ?? false

        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Button(action: toggleExpand) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 14, height: 14, alignment: .center)
                        .padding(4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(width: 22, height: 22)

                Image(systemName: "folder.fill")
                    .foregroundColor(.accentColor)
                    .frame(width: 16, alignment: .leading)

                Text(projectName)
                    .font(.headline)
                    .lineLimit(1)

                if isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                }

                Spacer()

                HStack(spacing: 6) {
                    if totalChanges > 0 {
                        StatusBadge(count: totalChanges, color: .orange, icon: "pencil")
                    }
                    if totalUnpushed > 0 {
                        StatusBadge(count: totalUnpushed, color: .blue, icon: "arrow.up")
                    }
                }
            }

            Text(localization.repositoriesCount(repositoryCount))
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 36)

            if !projectNote.isEmpty {
                Text(projectNote)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .padding(.leading, 36)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.clear)
        )
    }
}
