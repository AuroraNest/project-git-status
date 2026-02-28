import SwiftUI
import Combine

@MainActor
class MainViewModel: ObservableObject {
    @Published var projects: [Project] = []
    @Published var isLoading = false
    @Published var showingAddProject = false
    @Published var showingError = false
    @Published var errorMessage = ""
    @Published var selectedRepositoryId: UUID?
    @Published var defaultProjectId: UUID?
    @Published var menuBarMessage: String?

    private let persistence = PersistenceService.shared
    private let scanner = ProjectScanner()
    private let l10n = AppLocalization.shared

    private var refreshingRepositoryIDs: Set<UUID> = []
    private var isRefreshingAll = false

    init() {
        loadProjects()
    }

    var pinnedProjects: [Project] {
        projects.filter(\.isPinned)
    }

    var regularProjects: [Project] {
        projects.filter { !$0.isPinned }
    }

    // MARK: - 项目管理

    func loadProjects() {
        projects = persistence.loadProjects()
        applyProjectOrdering()
        saveProjects()
        defaultProjectId = persistence.loadDefaultProjectId()
        normalizeDefaultProjectSelection()

        Task {
            await rescanAllProjects()
        }
    }

    /// 重新扫描所有项目
    func rescanAllProjects() async {
        isLoading = true
        defer { isLoading = false }

        for projectIndex in projects.indices {
            let project = projects[projectIndex]
            do {
                let repos = try await scanner.scanForRepositories(
                    in: project.path,
                    projectId: project.id
                )
                projects[projectIndex].repositories = repos
                projects[projectIndex].lastScannedAt = Date()

                await refreshRepositories(repos)
            } catch {
                print("扫描项目失败: \(error)")
            }
        }

        normalizeDefaultProjectSelection()
        syncSelectedRepositoryWithCurrentProjects()
        saveProjects()
    }

    func addProject(at path: String) async {
        let name = Project.nameFromPath(path)
        var project = Project(
            name: name,
            path: path,
            sortOrder: regularProjects.count
        )

        do {
            project.repositories = try await scanner.scanForRepositories(
                in: path,
                projectId: project.id
            )
            project.lastScannedAt = Date()

            projects.append(project)
            applyProjectOrdering()
            if defaultProjectId == nil {
                defaultProjectId = project.id
                persistence.saveDefaultProjectId(defaultProjectId)
            }
            saveProjects()

            await refreshRepositories(project.repositories)
        } catch {
            showError(l10n.scanRepositoriesFailed(error.localizedDescription))
        }
    }

    func removeProject(_ project: Project) {
        projects.removeAll { $0.id == project.id }
        applyProjectOrdering()

        if let selectedRepositoryId,
           getRepository(byId: selectedRepositoryId) == nil {
            self.selectedRepositoryId = nil
        }

        normalizeDefaultProjectSelection()
        saveProjects()
    }

    func toggleProjectExpanded(_ project: Project) {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else { return }
        projects[index].isExpanded.toggle()
        saveProjects()
    }

    func setProjectExpanded(_ project: Project, isExpanded: Bool) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index].isExpanded = isExpanded
            saveProjects()
        }
    }

    func setProjectPinned(_ project: Project, isPinned: Bool) {
        var pinned = pinnedProjects
        var regular = regularProjects

        if project.isPinned {
            pinned.removeAll { $0.id == project.id }
        } else {
            regular.removeAll { $0.id == project.id }
        }

        var updatedProject = project
        updatedProject.isPinned = isPinned

        if isPinned {
            pinned.append(updatedProject)
        } else {
            regular.append(updatedProject)
        }

        persistProjectOrdering(pinned: pinned, regular: regular)
    }

    func updateProjectNote(_ project: Project, note: String) {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else { return }
        projects[index].note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        saveProjects()
    }

    func movePinnedProjects(from offsets: IndexSet, to destination: Int) {
        var pinned = pinnedProjects
        let regular = regularProjects
        pinned.move(fromOffsets: offsets, toOffset: destination)
        persistProjectOrdering(pinned: pinned, regular: regular)
    }

    func moveRegularProjects(from offsets: IndexSet, to destination: Int) {
        let pinned = pinnedProjects
        var regular = regularProjects
        regular.move(fromOffsets: offsets, toOffset: destination)
        persistProjectOrdering(pinned: pinned, regular: regular)
    }

    func moveProject(draggedProjectId: UUID, before targetProjectId: UUID) {
        guard draggedProjectId != targetProjectId else { return }

        var pinned = pinnedProjects
        var regular = regularProjects

        let draggedFromPinned = pinned.contains(where: { $0.id == draggedProjectId })
        let targetInPinned = pinned.contains(where: { $0.id == targetProjectId })

        var draggedProject: Project
        if draggedFromPinned,
           let index = pinned.firstIndex(where: { $0.id == draggedProjectId }) {
            draggedProject = pinned.remove(at: index)
        } else if let index = regular.firstIndex(where: { $0.id == draggedProjectId }) {
            draggedProject = regular.remove(at: index)
        } else {
            return
        }

        draggedProject.isPinned = targetInPinned

        if targetInPinned {
            let targetIndex = pinned.firstIndex(where: { $0.id == targetProjectId }) ?? pinned.count
            pinned.insert(draggedProject, at: targetIndex)
        } else {
            let targetIndex = regular.firstIndex(where: { $0.id == targetProjectId }) ?? regular.count
            regular.insert(draggedProject, at: targetIndex)
        }

        persistProjectOrdering(pinned: pinned, regular: regular)
    }

    func rescanProject(_ project: Project) async {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else { return }

        do {
            let repos = try await scanner.scanForRepositories(
                in: project.path,
                projectId: project.id
            )
            projects[index].repositories = repos
            projects[index].lastScannedAt = Date()

            await refreshRepositories(repos)
            normalizeDefaultProjectSelection()
            syncSelectedRepositoryWithCurrentProjects()
            saveProjects()
        } catch {
            showError(l10n.scanRepositoriesFailed(error.localizedDescription))
        }
    }

    func setDefaultProject(_ projectId: UUID?) {
        defaultProjectId = projectId
        normalizeDefaultProjectSelection()
    }

    var defaultProject: Project? {
        guard let defaultProjectId else { return projects.first }
        return projects.first(where: { $0.id == defaultProjectId }) ?? projects.first
    }

    // MARK: - 仓库状态

    func refreshAll() async {
        guard !isRefreshingAll else { return }
        isRefreshingAll = true
        isLoading = true
        defer {
            isLoading = false
            isRefreshingAll = false
        }

        let repos = projects.flatMap(\.repositories)
        await refreshRepositories(repos)
    }

    func refreshDefaultProject() async {
        guard let project = defaultProject else { return }
        await refreshRepositories(project.repositories)
    }

    func quickCommitAndPushModifiedFiles(repositoryId: UUID, message: String) async -> Bool {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else {
            menuBarMessage = l10n.t(.enterCommitLogMessage)
            return false
        }

        guard let repository = getRepository(byId: repositoryId) else {
            menuBarMessage = l10n.t(.targetRepositoryNotFound)
            return false
        }

        guard refreshingRepositoryIDs.insert(repository.id).inserted else {
            menuBarMessage = l10n.t(.repoBusyRetryLater)
            return false
        }

        mutateRepository(projectId: repository.parentProjectId, repoId: repository.id) {
            $0.isLoading = true
        }

        defer {
            refreshingRepositoryIDs.remove(repository.id)
            mutateRepository(projectId: repository.parentProjectId, repoId: repository.id) {
                $0.isLoading = false
            }
        }

        do {
            let gitService = GitService()
            let latestStatus = try await gitService.getStatus(in: repository.path)
            let modifiedPaths = latestStatus.modifiedFiles
                .filter { $0.status != .conflicted }
                .map(\.path)

            guard !modifiedPaths.isEmpty else {
                mutateRepository(projectId: repository.parentProjectId, repoId: repository.id) {
                    $0.status = latestStatus
                    $0.currentBranch = latestStatus.currentBranch
                    $0.lastError = nil
                }
                menuBarMessage = l10n.t(.noModifiedFilesToCommit)
                return false
            }

            try await gitService.unstageAll(in: repository.path)
            try await gitService.stageFiles(modifiedPaths.map { $0 }, in: repository.path)
            try await gitService.commit(message: trimmedMessage, in: repository.path)
            try await gitService.push(in: repository.path)

            let finalStatus = try await gitService.getStatus(in: repository.path)
            mutateRepository(projectId: repository.parentProjectId, repoId: repository.id) {
                $0.status = finalStatus
                $0.currentBranch = finalStatus.currentBranch
                $0.lastError = nil
            }

            menuBarMessage = l10n.quickCommitPushSuccess(modifiedPaths.count)
            return true
        } catch {
            mutateRepository(projectId: repository.parentProjectId, repoId: repository.id) {
                $0.lastError = error.localizedDescription
            }
            menuBarMessage = l10n.t(.commitOrPushFailed)
            return false
        }
    }

    func refreshRepository(_ repository: GitRepository) async {
        guard refreshingRepositoryIDs.insert(repository.id).inserted else { return }
        mutateRepository(projectId: repository.parentProjectId, repoId: repository.id) {
            $0.isLoading = true
        }

        defer {
            refreshingRepositoryIDs.remove(repository.id)
            mutateRepository(projectId: repository.parentProjectId, repoId: repository.id) {
                $0.isLoading = false
            }
        }

        do {
            let gitService = GitService()
            let status = try await gitService.getStatus(in: repository.path)
            mutateRepository(projectId: repository.parentProjectId, repoId: repository.id) {
                $0.status = status
                $0.currentBranch = status.currentBranch
                $0.lastError = nil
            }
        } catch {
            mutateRepository(projectId: repository.parentProjectId, repoId: repository.id) {
                $0.status = nil
                $0.lastError = error.localizedDescription
            }
        }
    }

    /// 供详情页在完成操作后，把最新状态同步回侧边栏/菜单栏面板
    func syncRepositoryRuntimeState(projectId: UUID, repoId: UUID, status: GitStatus?, lastError: String?) {
        mutateRepository(projectId: projectId, repoId: repoId) {
            $0.status = status
            if let status {
                $0.currentBranch = status.currentBranch
            }
            $0.lastError = lastError
            // 详情页已经拿到最新状态了，就不要继续显示“转圈”
            $0.isLoading = false
        }
    }

    // MARK: - 获取仓库

    func getRepository(byId id: UUID) -> GitRepository? {
        for project in projects {
            if let repo = project.repositories.first(where: { $0.id == id }) {
                return repo
            }
        }
        return nil
    }

    func setSelectedRepository(_ repositoryId: UUID?) {
        selectedRepositoryId = repositoryId
    }

    func clearMenuBarMessage() {
        menuBarMessage = nil
    }

    // MARK: - UI 操作

    func showAddProjectDialog() {
        showingAddProject = true
    }

    func openInTerminal(_ repository: GitRepository) {
        let script = """
        tell application "Terminal"
            do script "cd '\(repository.path)'"
            activate
        end tell
        """

        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }

    func openInFinder(_ repository: GitRepository) {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: repository.path)
    }

    // MARK: - Private

    private func saveProjects() {
        persistence.saveProjects(projects)
    }

    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }

    private func refreshRepositories(_ repos: [GitRepository]) async {
        await withTaskGroup(of: Void.self) { group in
            for repo in repos {
                group.addTask { @MainActor in
                    await self.refreshRepository(repo)
                }
            }
        }
    }

    private func normalizeDefaultProjectSelection() {
        if let defaultProjectId, projects.contains(where: { $0.id == defaultProjectId }) {
            persistence.saveDefaultProjectId(defaultProjectId)
            return
        }

        defaultProjectId = projects.first?.id
        persistence.saveDefaultProjectId(defaultProjectId)
    }

    private func syncSelectedRepositoryWithCurrentProjects() {
        guard let selectedRepositoryId else { return }
        if getRepository(byId: selectedRepositoryId) == nil {
            self.selectedRepositoryId = nil
        }
    }

    private func applyProjectOrdering() {
        projects.sort {
            if $0.isPinned != $1.isPinned {
                return $0.isPinned && !$1.isPinned
            }
            if $0.sortOrder != $1.sortOrder {
                return $0.sortOrder < $1.sortOrder
            }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }

        var pinnedOrder = 0
        var regularOrder = 0
        for index in projects.indices {
            if projects[index].isPinned {
                projects[index].sortOrder = pinnedOrder
                pinnedOrder += 1
            } else {
                projects[index].sortOrder = regularOrder
                regularOrder += 1
            }
        }
    }

    private func persistProjectOrdering(pinned: [Project], regular: [Project]) {
        var pinned = pinned
        var regular = regular

        for index in pinned.indices {
            pinned[index].isPinned = true
            pinned[index].sortOrder = index
        }

        for index in regular.indices {
            regular[index].isPinned = false
            regular[index].sortOrder = index
        }

        projects = pinned + regular
        saveProjects()
    }

    private func mutateRepository(
        projectId: UUID,
        repoId: UUID,
        _ mutate: (inout GitRepository) -> Void
    ) {
        guard let projectIndex = projects.firstIndex(where: { $0.id == projectId }),
              let repoIndex = projects[projectIndex].repositories.firstIndex(where: { $0.id == repoId }) else {
            return
        }

        mutate(&projects[projectIndex].repositories[repoIndex])
        projects = projects
    }
}
