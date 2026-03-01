import SwiftUI
import AppKit

struct CommitRowView: View {
    let commit: GitCommit
    var isSelected: Bool = false
    @EnvironmentObject var viewModel: RepositoryViewModel
    @EnvironmentObject var localization: AppLocalization

    @State private var showingResetHardFirstConfirm = false
    @State private var showingResetHardFinalConfirm = false

    var body: some View {
        HStack(spacing: 8) {
            // Hash
            Text(commit.id)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(isSelected ? .white : .secondary)
                .frame(width: 60, alignment: .leading)

            // 提交信息
            VStack(alignment: .leading, spacing: 2) {
                Text(commit.message)
                    .font(.body)
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(commit.author)
                    Text("·")
                    Text(commit.relativeDate)
                }
                .font(.caption)
                .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            }

            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor : Color.clear)
        )
        .contentShape(Rectangle())
        .contextMenu {
            // 复制 Hash
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(commit.fullHash, forType: .string)
            } label: {
                Label(localization.t(.copyCommitHash), systemImage: "doc.on.doc")
            }

            Divider()

            // Revert
            Button {
                Task {
                    await viewModel.revertCommit(commit)
                }
            } label: {
                Label(localization.t(.revertCommit), systemImage: "arrow.uturn.backward")
            }
            .disabled(viewModel.isRepoBusy)

            // Cherry-pick
            Button {
                Task {
                    await viewModel.cherryPickCommit(commit)
                }
            } label: {
                Label(localization.t(.cherryPick), systemImage: "leaf")
            }
            .disabled(viewModel.isRepoBusy)

            Divider()

            // 软重置
            Button {
                Task {
                    await viewModel.resetSoftToCommit(commit)
                }
            } label: {
                Label(localization.t(.resetSoftTo), systemImage: "arrow.counterclockwise")
            }
            .disabled(viewModel.isRepoBusy)

            // 硬重置（危险）
            Button(role: .destructive) {
                showingResetHardFirstConfirm = true
            } label: {
                Label(localization.t(.resetHardTo), systemImage: "exclamationmark.triangle")
            }
            .disabled(viewModel.isRepoBusy)
        }
        .alert(localization.t(.continueConfirm), isPresented: $showingResetHardFirstConfirm) {
            Button(localization.t(.cancel), role: .cancel) {}
            Button(localization.t(.continueConfirm), role: .destructive) {
                showingResetHardFinalConfirm = true
            }
        } message: {
            Text(localization.t(.resetHardWarning))
        }
        .alert(localization.t(.finalConfirm), isPresented: $showingResetHardFinalConfirm) {
            Button(localization.t(.cancel), role: .cancel) {}
            Button(localization.t(.confirm), role: .destructive) {
                Task {
                    await viewModel.resetHardToCommit(commit)
                }
            }
        } message: {
            Text(localization.t(.resetHardFinalWarning))
        }
    }
}
