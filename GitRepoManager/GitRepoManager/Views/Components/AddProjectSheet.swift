import SwiftUI

struct AddProjectSheet: View {
    @EnvironmentObject var viewModel: MainViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPath: String = ""
    @State private var isSelecting = false

    var body: some View {
        VStack(spacing: 20) {
            // 标题
            Text("添加项目")
                .font(.title2)
                .fontWeight(.semibold)

            // 说明
            Text("选择项目根目录，应用会自动扫描其中的 Git 仓库")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // 路径显示
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundColor(.accentColor)

                if selectedPath.isEmpty {
                    Text("未选择目录")
                        .foregroundColor(.secondary)
                } else {
                    Text(selectedPath)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                Button("选择...") {
                    selectFolder()
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            // 按钮
            HStack {
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("添加") {
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
        panel.title = "选择项目目录"
        panel.message = "选择包含 Git 仓库的项目目录"
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

