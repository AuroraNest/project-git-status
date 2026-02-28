import Foundation

/// 项目扫描服务
actor ProjectScanner {

    /// 智能递归扫描目录中的 Git 仓库
    /// 如果当前目录不是 git 仓库，则继续向下扫描
    func scanForRepositories(in directory: String, projectId: UUID, basePath: String? = nil) async throws -> [GitRepository] {
        let fileManager = FileManager.default
        let url = URL(fileURLWithPath: directory)
        let base = basePath ?? directory

        var repositories: [GitRepository] = []

        // 检查当前目录是否是 git 仓库
        if isGitRepository(at: directory) {
            let name = url.lastPathComponent
            let relativePath = directory == base ? "" : String(directory.dropFirst(base.count + 1))
            repositories.append(GitRepository(
                name: name,
                path: directory,
                parentProjectId: projectId,
                relativePath: relativePath
            ))
            // 如果是 git 仓库，不再向下扫描
            return repositories
        }

        // 扫描子目录
        guard let contents = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return repositories
        }

        for itemURL in contents {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: itemURL.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                continue
            }

            // 跳过常见的非项目目录
            let dirName = itemURL.lastPathComponent
            let skipDirs = ["node_modules", ".git", "build", "dist", "target", ".idea", ".vscode", "Pods", "DerivedData"]
            if skipDirs.contains(dirName) {
                continue
            }

            // 递归扫描子目录
            let subRepos = try await scanForRepositories(
                in: itemURL.path,
                projectId: projectId,
                basePath: base
            )
            repositories.append(contentsOf: subRepos)
        }

        return repositories
    }

    /// 检查目录是否是 Git 仓库
    private func isGitRepository(at path: String) -> Bool {
        let gitPath = URL(fileURLWithPath: path).appendingPathComponent(".git")
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: gitPath.path, isDirectory: &isDirectory)
    }
}
