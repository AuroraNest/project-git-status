import SwiftUI

struct ProjectRowView: View {
    let projectId: UUID
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

        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .foregroundColor(.accentColor)
                    .frame(width: 16, alignment: .leading)

                Text(projectName)
                    .font(.headline)
                    .lineLimit(1)

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
                .padding(.leading, 24)
        }
        .padding(.vertical, 2)
    }
}
