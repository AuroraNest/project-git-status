import SwiftUI
import AppKit

@main
struct GitRepoManagerApp: App {
    @StateObject private var mainViewModel = MainViewModel()
    @StateObject private var statusBarController = StatusBarController()

    var body: some Scene {
        WindowGroup(id: "main") {
            MainView()
                .environmentObject(mainViewModel)
                .frame(minWidth: 900, minHeight: 600)
                .onAppear {
                    statusBarController.configureIfNeeded(with: mainViewModel)
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(after: .newItem) {
                Button("添加项目...") {
                    mainViewModel.showAddProjectDialog()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Divider()

                Button("刷新所有仓库") {
                    Task {
                        await mainViewModel.refreshAll()
                    }
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }
    }
}

final class StatusBarController: ObservableObject {
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()

    func configureIfNeeded(with viewModel: MainViewModel) {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "externaldrive.badge.checkmark", accessibilityDescription: "Git 状态")
            button.imagePosition = .imageOnly
            button.toolTip = "Git 仓库状态"
            button.target = self
            button.action = #selector(togglePopover(_:))
        }
        statusItem = item

        popover.behavior = .transient  // 点击其他区域自动收起
        popover.animates = true
        popover.contentSize = NSSize(width: 520, height: 560)
        popover.contentViewController = NSHostingController(
            rootView: MenuBarPanelView(
                openMainWindow: { [weak self] in
                    self?.openMainWindow()
                },
                closePanel: { [weak self] in
                    self?.popover.performClose(nil)
                }
            )
            .environmentObject(viewModel)
        )
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func openMainWindow() {
        popover.performClose(nil)
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.isVisible }) ?? NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }
}

struct MenuBarPanelView: View {
    @EnvironmentObject var viewModel: MainViewModel
    let openMainWindow: () -> Void
    let closePanel: () -> Void

    @State private var selectedRepositoryId: UUID?
    @State private var commitMessage: String = ""
    @AppStorage("menuBarChangeTipsVisible") private var changeTipsVisible = true
    @AppStorage("menuBarChangeTipsCollapsed") private var changeTipsCollapsed = false

    private var defaultProject: Project? {
        viewModel.defaultProject
    }

    private var repositories: [GitRepository] {
        defaultProject?.repositories ?? []
    }

    private var repositoriesWithChanges: [GitRepository] {
        repositories.filter { ($0.status?.totalChangedCount ?? 0) > 0 }
    }

    private var selectedRepository: GitRepository? {
        guard let selectedRepositoryId else { return repositories.first }
        return repositories.first(where: { $0.id == selectedRepositoryId }) ?? repositories.first
    }

    private var trimmedCommitMessage: String {
        commitMessage.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canQuickCommitPush: Bool {
        guard let selectedRepository else { return false }
        return !trimmedCommitMessage.isEmpty && !selectedRepository.isLoading
    }

    private var changedTrackedFiles: [GitFile] {
        guard let status = selectedRepository?.status else { return [] }
        return status.stagedFiles + status.modifiedFiles
    }

    private var modifiedDirectorySummaries: [(directory: String, count: Int)] {
        let grouped = Dictionary(grouping: changedTrackedFiles) { file in
            file.directoryPath.isEmpty ? "仓库根目录" : file.directoryPath
        }
        return grouped
            .map { (directory: $0.key, count: $0.value.count) }
            .sorted {
                if $0.count == $1.count {
                    return $0.directory < $1.directory
                }
                return $0.count > $1.count
            }
    }

    private var changedFilePreviews: [String] {
        Array(changedTrackedFiles.map(\.path).prefix(4))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Git 快捷面板", systemImage: "bolt.circle")
                    .font(.headline)
                Spacer()
                Button("收起") {
                    closePanel()
                }
                .buttonStyle(.bordered)
            }

            if viewModel.projects.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("还没有添加项目")
                        .foregroundColor(.secondary)
                    Button("打开主窗口添加项目") {
                        openMainWindow()
                        viewModel.showAddProjectDialog()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("默认项目")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Picker("默认项目", selection: defaultProjectBinding) {
                        ForEach(viewModel.projects) { project in
                            Text(project.name).tag(Optional(project.id))
                        }
                    }
                    .pickerStyle(.menu)
                }

                if repositories.isEmpty {
                    Text("默认项目下没有仓库")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("目标仓库（仅显示有修改）")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        if repositoriesWithChanges.isEmpty {
                            Text("当前没有有修改的仓库，先点“刷新”")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(repositoriesWithChanges) { repo in
                                        Button {
                                            selectedRepositoryId = repo.id
                                        } label: {
                                            HStack(spacing: 6) {
                                                Text(repo.name)
                                                    .lineLimit(1)
                                                Text("\(repo.status?.totalChangedCount ?? 0)")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(
                                                (selectedRepository?.id == repo.id ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.10))
                                            )
                                            .cornerRadius(8)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        Button("查看详情") {
                            if let selectedRepository {
                                viewModel.setSelectedRepository(selectedRepository.id)
                            }
                            openMainWindow()
                        }
                        .buttonStyle(.bordered)

                        Button("刷新") {
                            guard let selectedRepository else { return }
                            Task {
                                await viewModel.refreshRepository(selectedRepository)
                            }
                        }
                        .buttonStyle(.bordered)

                        Button("Finder") {
                            guard let selectedRepository else { return }
                            viewModel.openInFinder(selectedRepository)
                        }
                        .buttonStyle(.bordered)

                        Button("终端") {
                            guard let selectedRepository else { return }
                            viewModel.openInTerminal(selectedRepository)
                        }
                        .buttonStyle(.bordered)
                    }

                    if let status = selectedRepository?.status {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("变更提示")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()

                                if changeTipsVisible {
                                    Button(changeTipsCollapsed ? "展开" : "收起") {
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            changeTipsCollapsed.toggle()
                                        }
                                    }
                                    .buttonStyle(.borderless)
                                    .font(.caption)

                                    Button("隐藏") {
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            changeTipsVisible = false
                                        }
                                    }
                                    .buttonStyle(.borderless)
                                    .font(.caption)
                                } else {
                                    Button("显示") {
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            changeTipsVisible = true
                                        }
                                    }
                                    .buttonStyle(.borderless)
                                    .font(.caption)
                                }
                            }

                            if changeTipsVisible && !changeTipsCollapsed {
                                HStack(spacing: 8) {
                                    Label("已暂存 \(status.stagedFiles.count)", systemImage: "checkmark.circle")
                                    Label("已修改 \(status.modifiedFiles.count)", systemImage: "pencil.circle")
                                    Label("未跟踪 \(status.untrackedFiles.count)", systemImage: "questionmark.circle")
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)

                                if modifiedDirectorySummaries.isEmpty {
                                    Text("当前没有已修改目录")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("已修改目录：")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        ForEach(Array(modifiedDirectorySummaries.prefix(3)), id: \.directory) { item in
                                            HStack(spacing: 6) {
                                                Image(systemName: "folder")
                                                    .foregroundColor(.secondary)
                                                Text(item.directory)
                                                    .lineLimit(1)
                                                Spacer()
                                                Text("\(item.count)")
                                                    .foregroundColor(.secondary)
                                            }
                                            .font(.caption)
                                        }
                                    }
                                }

                                if !changedFilePreviews.isEmpty {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("文件预览：")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        ForEach(changedFilePreviews, id: \.self) { path in
                                            Text(path)
                                                .font(.caption2)
                                                .lineLimit(1)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(10)
                        .background(Color.secondary.opacity(0.08))
                        .cornerRadius(10)
                    } else {
                        Text("暂无状态数据，点“刷新”即可看到变更目录")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("提交日志（仅提交并推送已修改文件）")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        TextField("输入提交日志...", text: $commitMessage)
                            .textFieldStyle(.roundedBorder)

                        Button {
                            guard let selectedRepository else { return }
                            Task {
                                let success = await viewModel.quickCommitAndPushModifiedFiles(
                                    repositoryId: selectedRepository.id,
                                    message: commitMessage
                                )
                                if success {
                                    commitMessage = ""
                                }
                            }
                        } label: {
                            Label("提交并推送已修改", systemImage: "paperplane.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canQuickCommitPush)
                    }
                }
            }

            if let message = viewModel.menuBarMessage, !message.isEmpty {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .frame(width: 500)
        .onAppear {
            syncSelectedRepository()
        }
        .onChange(of: repositories.map(\.id)) { _ in
            syncSelectedRepository()
        }
        .onChange(of: defaultProject?.id) { _ in
            syncSelectedRepository()
        }
    }

    private var defaultProjectBinding: Binding<UUID?> {
        Binding(
            get: { viewModel.defaultProject?.id },
            set: { viewModel.setDefaultProject($0) }
        )
    }

    private func syncSelectedRepository() {
        let preferred = repositoriesWithChanges.first?.id
        let availableIds = Set(repositories.map(\.id))
        if let selectedRepositoryId, availableIds.contains(selectedRepositoryId) {
            return
        }
        self.selectedRepositoryId = preferred ?? repositories.first?.id
    }
}
