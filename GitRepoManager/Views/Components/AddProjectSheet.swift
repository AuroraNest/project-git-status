import SwiftUI

struct AddProjectSheet: View {
    @EnvironmentObject var viewModel: MainViewModel
    @EnvironmentObject var localization: AppLocalization
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPath: String = ""
    @State private var isSelecting = false

    var body: some View {
        VStack(spacing: 20) {
            // 标题
            Text(localization.t(.addProjectTitle))
                .font(.title2)
                .fontWeight(.semibold)

            // 说明
            Text(localization.t(.chooseProjectRootDirectory))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // 路径显示
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundColor(.accentColor)

                if selectedPath.isEmpty {
                    Text(localization.t(.noDirectorySelected))
                        .foregroundColor(.secondary)
                } else {
                    Text(selectedPath)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                Button("\(localization.t(.choose))...") {
                    selectFolder()
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            // 按钮
            HStack {
                Button(localization.t(.cancel)) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(localization.t(.addProject)) {
                    Task {
                        await viewModel.addProject(at: selectedPath)
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedPath.isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 450)
        .onAppear {
            // 自动打开选择对话框
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                selectFolder()
            }
        }
    }

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.title = localization.t(.chooseProjectDirectory)
        panel.message = localization.t(.chooseDirectoryContainingGitRepos)
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        if panel.runModal() == .OK {
            if let url = panel.url {
                selectedPath = url.path
            }
        }
    }
}
