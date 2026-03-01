import Foundation

/// 编辑器类型
enum EditorType: String, Codable, CaseIterable, Identifiable {
    case vscode = "vscode"
    case cursor = "cursor"
    case xcode = "xcode"
    case idea = "idea"
    case pycharm = "pycharm"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .vscode: return "VS Code"
        case .cursor: return "Cursor"
        case .xcode: return "Xcode"
        case .idea: return "IntelliJ IDEA"
        case .pycharm: return "PyCharm"
        }
    }

    var appPath: String {
        switch self {
        case .vscode: return "/Applications/Visual Studio Code.app"
        case .cursor: return "/Applications/Cursor.app"
        case .xcode: return "/Applications/Xcode.app"
        case .idea: return "/Applications/IntelliJ IDEA.app"
        case .pycharm: return "/Applications/PyCharm.app"
        }
    }

    // 有些 IDE 有多个可能的路径
    var alternatePaths: [String] {
        switch self {
        case .pycharm: return [
            "/Applications/PyCharm.app",
            "/Applications/PyCharm CE.app",
            "/Applications/PyCharm Professional.app"
        ]
        case .idea: return [
            "/Applications/IntelliJ IDEA.app",
            "/Applications/IntelliJ IDEA CE.app",
            "/Applications/IntelliJ IDEA Ultimate.app"
        ]
        default: return [appPath]
        }
    }

    var installedPath: String? {
        for path in alternatePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return nil
    }

    var isInstalled: Bool {
        installedPath != nil
    }

    static var installedEditors: [EditorType] {
        allCases.filter { $0.isInstalled }
    }
}

/// 持久化服务
class PersistenceService {
    static let shared = PersistenceService()

    private let fileManager = FileManager.default
    private let userDefaults = UserDefaults.standard
    private let legacyProjectsKey = "savedProjects"

    private struct AppSettings: Codable {
        var defaultProjectId: UUID?
        var language: AppLanguage?
        var preferredEditor: EditorType?
    }

    private var configDirectoryURL: URL {
        URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
            .appendingPathComponent(".project-git-status", isDirectory: true)
            .appendingPathComponent("config", isDirectory: true)
    }

    private var projectsFileURL: URL {
        configDirectoryURL.appendingPathComponent("projects.json")
    }

    private var settingsFileURL: URL {
        configDirectoryURL.appendingPathComponent("settings.json")
    }

    private var legacyJSONFileURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("GitRepoManager", isDirectory: true)
        return appFolder.appendingPathComponent("projects.json")
    }

    private init() {
        ensureConfigDirectoryExists()
    }

    private func ensureConfigDirectoryExists() {
        try? fileManager.createDirectory(at: configDirectoryURL, withIntermediateDirectories: true)
    }

    /// 保存项目列表
    func saveProjects(_ projects: [Project]) {
        do {
            ensureConfigDirectoryExists()
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(projects)
            try data.write(to: projectsFileURL, options: .atomic)
        } catch {
            print("保存项目失败: \(error)")
        }
    }

    /// 加载项目列表
    func loadProjects() -> [Project] {
        ensureConfigDirectoryExists()

        // 新路径：~/.project-git-status/config/projects.json
        if let data = try? Data(contentsOf: projectsFileURL) {
            do {
                let decoder = JSONDecoder()
                return try decoder.decode([Project].self, from: data)
            } catch {
                print("从新配置目录加载失败: \(error)")
            }
        }

        // 兼容旧版：UserDefaults
        if let data = userDefaults.data(forKey: legacyProjectsKey) {
            do {
                let decoder = JSONDecoder()
                let projects = try decoder.decode([Project].self, from: data)
                saveProjects(projects)  // 迁移到新目录
                return projects
            } catch {
                print("从 UserDefaults 加载失败: \(error)")
            }
        }

        // 兼容旧版：Application Support JSON
        if let data = try? Data(contentsOf: legacyJSONFileURL) {
            do {
                let decoder = JSONDecoder()
                let projects = try decoder.decode([Project].self, from: data)
                saveProjects(projects)  // 迁移到新目录
                return projects
            } catch {
                print("从旧 JSON 文件加载失败: \(error)")
            }
        }

        return []
    }

    func saveDefaultProjectId(_ projectId: UUID?) {
        do {
            ensureConfigDirectoryExists()
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            var settings = loadSettings()
            settings.defaultProjectId = projectId
            let data = try encoder.encode(settings)
            try data.write(to: settingsFileURL, options: .atomic)
        } catch {
            print("保存默认项目失败: \(error)")
        }
    }

    func loadDefaultProjectId() -> UUID? {
        loadSettings().defaultProjectId
    }

    func saveLanguage(_ language: AppLanguage) {
        do {
            ensureConfigDirectoryExists()
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            var settings = loadSettings()
            settings.language = language
            let data = try encoder.encode(settings)
            try data.write(to: settingsFileURL, options: .atomic)
        } catch {
            print("保存语言设置失败: \(error)")
        }
    }

    func loadLanguage() -> AppLanguage? {
        loadSettings().language
    }

    func savePreferredEditor(_ editor: EditorType?) {
        do {
            ensureConfigDirectoryExists()
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            var settings = loadSettings()
            settings.preferredEditor = editor
            let data = try encoder.encode(settings)
            try data.write(to: settingsFileURL, options: .atomic)
        } catch {
            print("保存编辑器设置失败: \(error)")
        }
    }

    func loadPreferredEditor() -> EditorType? {
        loadSettings().preferredEditor
    }

    private func loadSettings() -> AppSettings {
        guard let data = try? Data(contentsOf: settingsFileURL) else {
            return AppSettings(defaultProjectId: nil, language: nil)
        }

        do {
            return try JSONDecoder().decode(AppSettings.self, from: data)
        } catch {
            print("读取设置失败: \(error)")
            return AppSettings(defaultProjectId: nil, language: nil)
        }
    }
}
