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
    private let gitService = GitService()
    private let l10n = AppLocalization.shared

    private var refreshingRepositoryIDs: Set<UUID> = []
    private var isRefreshingAll = false

    init() {
        loadProjects()
    }

    // MARK: - 项目管理

    func loadProjects() {
        projects = persistence.loadProjects()
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

                for repo in repos {
                    await refreshRepository(repo)
                }
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
        var project = Project(name: name, path: path)

        do {
            project.repositories = try await scanner.scanForRepositories(
                in: path,
                projectId: project.id
            )
            project.lastScannedAt = Date()

            projects.append(project)
            if defaultProjectId == nil {
                defaultProjectId = project.id
                persistence.saveDefaultProjectId(defaultProjectId)
            }
            saveProjects()

            for repo in project.repositories {
                await refreshRepository(repo)
            }
        } catch {
            showError(l10n.scanRepositoriesFailed(error.localizedDescription))
        }
    }

    func removeProject(_ project: Project) {
        projects.removeAll { $0.id == project.id }

        if let selectedRepositoryId,
           getRepository(byId: selectedRepositoryId) == nil {
            self.selectedRepositoryId = nil
        }

        normalizeDefaultProjectSelection()
        saveProjects()
    }

    func setProjectExpanded(_ project: Project, isExpanded: Bool) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index].isExpanded = isExpanded
            saveProjects()
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
        for repo in repos {
            await refreshRepository(repo)
        }
    }

    func refreshDefaultProject() async {
        guard let project = defaultProject else { return }
        let repos = project.repositories
        for repo in repos {
            await refreshRepository(repo)
        }
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
            let status = try await gitService.getStatus(in: repository.path)
            mutateRepository(projectId: repository.parentProjectId, repoId: repository.id) {
                $0.status = status
                $0.currentBranch = status.currentBranch
                $0.lastError = nil
            }
        } catch {
            mutateRepository(projectId: repository.parentProjectId, repoId: repository.id) {
                $0.lastError = error.localizedDescription
            }
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
