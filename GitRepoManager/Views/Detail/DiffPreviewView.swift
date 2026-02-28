import SwiftUI

struct DiffPreviewView: View {
    @EnvironmentObject var localization: AppLocalization
    let file: GitFile
    @ObservedObject var viewModel: RepositoryViewModel
    @State private var diffContent: String = ""
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 文件路径标题
            HStack {
                Image(systemName: file.status.iconName)
                    .foregroundColor(file.status.color)
                Text(file.path)
                    .font(.headline)
                Spacer()

                Text(file.status.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(file.status.color.opacity(0.15))
                    .foregroundColor(file.status.color)
                    .cornerRadius(4)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Diff 内容
            if isLoading {
                VStack {
                    ProgressView()
                    Text(localization.t(.loading))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = error {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if diffContent.isEmpty {
                VStack {
                    Image(systemName: "doc.text")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text(localization.t(.noDiffContent))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView([.horizontal, .vertical]) {
                    DiffContentView(content: diffContent)
                        .padding()
                }
            }
        }
        .task(id: file.id) {
            await loadDiff()
        }
    }

    private func loadDiff() async {
        isLoading = true
        error = nil

        let result = await viewModel.getDiff(for: file)
        diffContent = result

        if result.starts(with: localization.t(.unableToGetDiff)) {
            error = result
            diffContent = ""
        }

        isLoading = false
    }
}

struct DiffContentView: View {
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(content.components(separatedBy: "\n").enumerated()), id: \.offset) { index, line in
                HStack(spacing: 0) {
                    // 行号
                    Text("\(index + 1)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 40, alignment: .trailing)
                        .padding(.trailing, 8)

                    // 代码行
                    Text(line.isEmpty ? " " : line)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(colorForLine(line))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 1)
                .background(backgroundForLine(line))
            }
        }
        .textSelection(.enabled)
    }

    private func colorForLine(_ line: String) -> Color {
        if line.hasPrefix("+") && !line.hasPrefix("+++") {
            return .green
        } else if line.hasPrefix("-") && !line.hasPrefix("---") {
            return .red
        } else if line.hasPrefix("@@") {
            return .cyan
        } else if line.hasPrefix("diff") || line.hasPrefix("index") {
            return .secondary
        }
        return .primary
    }

    private func backgroundForLine(_ line: String) -> Color {
        if line.hasPrefix("+") && !line.hasPrefix("+++") {
            return .green.opacity(0.1)
        } else if line.hasPrefix("-") && !line.hasPrefix("---") {
            return .red.opacity(0.1)
        } else if line.hasPrefix("@@") {
            return .cyan.opacity(0.05)
        }
        return .clear
    }
}
