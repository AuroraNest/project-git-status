import SwiftUI
import AppKit

@main
struct GitRepoManagerApp: App {
    @StateObject private var mainViewModel = MainViewModel()
    @StateObject private var localization = AppLocalization.shared
    @StateObject private var statusBarController = StatusBarController()

    var body: some Scene {
        WindowGroup(id: "main") {
            MainView()
                .environmentObject(mainViewModel)
                .environmentObject(localization)
                .environmentObject(statusBarController)
                .frame(minWidth: 900, minHeight: 600)
                .onAppear {
                    statusBarController.configure(with: mainViewModel, localization: localization)
                }
                .onChange(of: localization.language) { _ in
                    statusBarController.configure(with: mainViewModel, localization: localization)
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(after: .newItem) {
                Button(localization.t(.addProjectEllipsis)) {
                    mainViewModel.showAddProjectDialog()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Divider()

                Button(localization.t(.refreshAllRepositories)) {
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
    private var openMainWindowById: (() -> Void)?

    func setMainWindowOpener(_ opener: @escaping () -> Void) {
        openMainWindowById = opener
    }

    func configure(with viewModel: MainViewModel, localization: AppLocalization) {
        if statusItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            if let button = item.button {
                button.imagePosition = .imageOnly
                button.target = self
                button.action = #selector(togglePopover(_:))
            }
            statusItem = item
        }

        if let button = statusItem?.button {
            button.image = NSImage(
                systemSymbolName: "externaldrive.badge.checkmark",
                accessibilityDescription: localization.t(.gitStatus)
            )
            button.toolTip = localization.t(.gitStatus)
        }

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
            .environmentObject(localization)
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
        let currentPopoverWindow = popover.contentViewController?.view.window
        popover.performClose(nil)

        // 激活应用
        NSApp.activate(ignoringOtherApps: true)

        // 查找主窗口
        for window in NSApp.windows {
            // 跳过当前菜单栏弹窗窗口，避免误判为“主窗口”
            if let currentPopoverWindow, window == currentPopoverWindow {
                continue
            }

            // 跳过菜单栏面板和其他系统窗口
            if window.className.contains("NSStatusBar") ||
               window.className.contains("NSPopover") ||
               window.className.contains("MenuBarExtra") {
                continue
            }

            // 仅命中可前置的主窗口，避免把已关闭/隐藏的残留窗口误判为主窗口
            let isUsableMainWindow =
                window.contentView != nil &&
                !window.isSheet &&
                window.canBecomeMain &&
                (window.isVisible || window.isMiniaturized)
            if isUsableMainWindow {
                if window.isMiniaturized {
                    window.deminiaturize(nil)
                }
                window.makeKeyAndOrderFront(nil)
                return
            }
        }

        // 如果主窗口都被关闭了，显式请求 SwiftUI 重新打开主窗口
        openMainWindowById?()

        // 兼容旧路径：继续尝试系统级前置动作
        NSApp.sendAction(#selector(NSWindow.makeKeyAndOrderFront(_:)), to: nil, from: nil)

        // 最后尝试：点击 Dock 图标效果
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            if NSApp.windows.filter({ $0.isVisible && $0.contentView != nil }).isEmpty {
                self?.openMainWindowById?()
                // 重新启动应用窗口
                NSApp.setActivationPolicy(.regular)
            }
        }
    }
}

struct MenuBarPanelView: View {
    @EnvironmentObject var viewModel: MainViewModel
    @EnvironmentObject var localization: AppLocalization
    let openMainWindow: () -> Void
    let closePanel: () -> Void

    @State private var selectedRepositoryId: UUID?
    @State private var commitMessage: String = ""
    @State private var showSuccessFlash = false
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
            file.directoryPath.isEmpty ? localization.t(.repositoryRootDirectory) : file.directoryPath
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

    private var currentBranch: String? {
        selectedRepository?.status?.currentBranch ?? selectedRepository?.currentBranch
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题栏
            HStack {
                Label(localization.t(.gitQuickPanel), systemImage: "bolt.circle")
                    .font(.headline)
                Spacer()

                Button {
                    openMainWindow()
                } label: {
                    Image(systemName: "macwindow")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help(localization.t(.viewDetails))

                Button {
                    closePanel()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            if viewModel.projects.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(localization.t(.noProjectsYet))
                        .foregroundColor(.secondary)
                    Button(localization.t(.openMainWindowToAddProject)) {
                        openMainWindow()
                        viewModel.showAddProjectDialog()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                // 默认项目选择
                VStack(alignment: .leading, spacing: 8) {
                    Text(localization.t(.defaultProject))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Picker(localization.t(.defaultProject), selection: defaultProjectBinding) {
                        ForEach(viewModel.projects) { project in
                            Text(project.name).tag(Optional(project.id))
                        }
                    }
                    .pickerStyle(.menu)
                }

                if repositories.isEmpty {
                    Text(localization.t(.noRepositoriesUnderDefaultProject))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    // 仓库选择（带分支名）
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(localization.t(.targetRepositoryOnlyChanged))
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            if let branch = currentBranch {
                                Spacer()
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.triangle.branch")
                                    Text(branch)
                                }
                                .font(.caption)
                                .foregroundColor(.accentColor)
                            }
                        }

                        if repositoriesWithChanges.isEmpty {
                            Text(localization.t(.noChangedRepositoriesRefreshFirst))
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

                    // 操作按钮（图标样式）
                    HStack(spacing: 6) {
                        // 编辑器
                        Button {
                            guard let selectedRepository else { return }
                            viewModel.openInIDE(selectedRepository)
                        } label: {
                            Image(systemName: "laptopcomputer")
                        }
                        .buttonStyle(.bordered)
                        .help(localization.t(.openInIDE))

                        // Finder
                        Button {
                            guard let selectedRepository else { return }
                            viewModel.openInFinder(selectedRepository)
                        } label: {
                            Image(systemName: "folder")
                        }
                        .buttonStyle(.bordered)
                        .help(localization.t(.showInFinder))

                        // 终端
                        Button {
                            guard let selectedRepository else { return }
                            viewModel.openInTerminal(selectedRepository)
                        } label: {
                            Image(systemName: "terminal")
                        }
                        .buttonStyle(.bordered)
                        .help(localization.t(.openInTerminal))

                        Divider()
                            .frame(height: 20)

                        // 刷新
                        Button {
                            guard let selectedRepository else { return }
                            Task {
                                await viewModel.refreshRepository(selectedRepository)
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .help(localization.t(.refresh))

                        // Pull
                        Button {
                            guard let selectedRepository else { return }
                            Task {
                                await quickPull(selectedRepository)
                            }
                        } label: {
                            Image(systemName: "arrow.down.circle")
                        }
                        .buttonStyle(.bordered)
                        .help(localization.t(.pull))

                        // Push
                        Button {
                            guard let selectedRepository else { return }
                            Task {
                                await quickPush(selectedRepository)
                            }
                        } label: {
                            Image(systemName: "arrow.up.circle")
                        }
                        .buttonStyle(.bordered)
                        .help(localization.t(.push))

                        Spacer()

                        // 查看详情
                        Button {
                            if let selectedRepository {
                                viewModel.setSelectedRepository(selectedRepository.id)
                            }
                            openMainWindow()
                        } label: {
                            Image(systemName: "arrow.up.right.square")
                        }
                        .buttonStyle(.bordered)
                        .help(localization.t(.viewDetails))
                    }

                    // 变更提示
                    if let status = selectedRepository?.status {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(localization.t(.changeTips))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()

                                Button(changeTipsCollapsed ? localization.t(.expand) : localization.t(.collapse)) {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        changeTipsCollapsed.toggle()
                                    }
                                }
                                .buttonStyle(.borderless)
                                .font(.caption)
                            }

                            if !changeTipsCollapsed {
                                HStack(spacing: 8) {
                                    Label("\(localization.t(.staged)) \(status.stagedFiles.count)", systemImage: "checkmark.circle")
                                    Label("\(localization.t(.modified)) \(status.modifiedFiles.count)", systemImage: "pencil.circle")
                                    Label("\(localization.t(.untracked)) \(status.untrackedFiles.count)", systemImage: "questionmark.circle")
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)

                                if modifiedDirectorySummaries.isEmpty {
                                    Text(localization.t(.noModifiedDirectories))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(localization.t(.modifiedDirectories))
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
                                        Text(localization.t(.filePreview))
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
                        Text(localization.t(.noStatusDataRefreshToSeeChangedDirectories))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // 提交区域
                    VStack(alignment: .leading, spacing: 8) {
                        Text(localization.t(.commitLogModifiedOnly))
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        TextEditor(text: $commitMessage)
                            .font(.body)
                            .frame(height: 50)
                            .padding(4)
                            .background(Color(NSColor.textBackgroundColor))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                            .cornerRadius(6)

                        Button {
                            guard let selectedRepository else { return }
                            Task {
                                let success = await viewModel.quickCommitAndPushModifiedFiles(
                                    repositoryId: selectedRepository.id,
                                    message: commitMessage
                                )
                                if success {
                                    commitMessage = ""
                                    showSuccessFlash = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        showSuccessFlash = false
                                    }
                                }
                            }
                        } label: {
                            Label(localization.t(.quickCommitPushModified), systemImage: "paperplane.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canQuickCommitPush)
                    }
                }
            }

            // 消息反馈
            if showSuccessFlash {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(localization.t(.commitAndPushSuccess))
                        .foregroundColor(.green)
                }
                .font(.caption)
                .transition(.opacity)
            } else if let message = viewModel.menuBarMessage, !message.isEmpty {
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

    private func quickPull(_ repository: GitRepository) async {
        let gitService = GitService()
        do {
            _ = try await gitService.pull(in: repository.path)
            await viewModel.refreshRepository(repository)
            viewModel.menuBarMessage = localization.t(.pullSuccess)
        } catch {
            viewModel.menuBarMessage = error.localizedDescription
        }
    }

    private func quickPush(_ repository: GitRepository) async {
        let gitService = GitService()
        do {
            try await gitService.push(in: repository.path)
            await viewModel.refreshRepository(repository)
            viewModel.menuBarMessage = localization.t(.pushSuccess)
        } catch {
            viewModel.menuBarMessage = error.localizedDescription
        }
    }
}
