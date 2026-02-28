import SwiftUI

struct ProjectRowView: View {
    let project: Project

    var totalChanges: Int {
        project.repositories.reduce(0) { sum, repo in
            sum + (repo.status?.totalChangedCount ?? 0)
        }
    }

    var totalUnpushed: Int {
        project.repositories.reduce(0) { sum, repo in
            sum + (repo.status?.aheadCount ?? 0)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .foregroundColor(.accentColor)
                    .frame(width: 16, alignment: .leading)

                Text(project.name)
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

            Text("\(project.repositories.count) 个仓库")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 24)
        }
        .padding(.vertical, 2)
    }
}
