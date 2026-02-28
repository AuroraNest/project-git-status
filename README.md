# Git 仓库管理器

一个原生 macOS SwiftUI 应用，用于管理多个项目的 Git 状态。

## 功能特性

- **项目管理**：添加项目根目录，自动递归扫描所有 Git 仓库
- **状态显示**：实时显示每个仓库的分支、修改数、未推送提交数
- **基础操作**：暂存、提交、拉取、推送
- **分支管理**：切换分支、创建分支、合并分支
- **内置终端**：执行任意 git 命令

## 如何创建 Xcode 项目

1. 打开 Xcode，选择 **File → New → Project**
2. 选择 **macOS → App**，点击 Next
3. 填写项目信息：
   - Product Name: `GitRepoManager`
   - Team: 你的开发者账号
   - Organization Identifier: 你的组织标识符
   - Interface: **SwiftUI**
   - Language: **Swift**
4. 选择保存位置（选择 `GitRepoManager` 目录的**上一级**目录）
5. 点击 Create

### 导入源文件

创建项目后：

1. 删除 Xcode 自动生成的 `ContentView.swift` 和 `GitRepoManagerApp.swift`
2. 在 Xcode 中右键项目 → **Add Files to "GitRepoManager"**
3. 选择 `GitRepoManager/GitRepoManager` 目录下的所有文件夹（App, Models, Services, ViewModels, Views）
4. 确保勾选 "Copy items if needed" 和 "Create groups"
5. 点击 Add

### 项目设置

1. 选择项目 → Targets → GitRepoManager
2. **General** 标签页：
   - Minimum Deployments: macOS 13.0
3. **Signing & Capabilities** 标签页：
   - 添加 "App Sandbox" capability
   - 在 App Sandbox 中启用：
     - File Access → User Selected File: Read/Write
     - 或者关闭 App Sandbox（开发时更方便）

### 运行

点击 Run (⌘R) 即可运行应用。

## 使用方法

1. 点击右上角 **+** 按钮添加项目目录
2. 应用会自动扫描目录下的所有 Git 仓库
3. 在左侧列表选择仓库查看详情
4. 使用按钮执行常用操作，或切换到终端标签页执行自定义命令

## 项目结构

```
GitRepoManager/
├── App/
│   └── GitRepoManagerApp.swift      # 应用入口
├── Models/
│   ├── Project.swift                # 项目模型
│   ├── GitRepository.swift          # 仓库模型
│   ├── GitStatus.swift              # 状态模型
│   ├── GitFile.swift                # 文件模型
│   └── GitBranch.swift              # 分支模型
├── Services/
│   ├── GitCommandRunner.swift       # Git 命令执行器
│   ├── GitService.swift             # Git 服务层
│   ├── ProjectScanner.swift         # 项目扫描器
│   └── PersistenceService.swift     # 持久化服务
├── ViewModels/
│   ├── MainViewModel.swift          # 主视图模型
│   ├── RepositoryViewModel.swift    # 仓库视图模型
│   └── TerminalViewModel.swift      # 终端视图模型
└── Views/
    ├── MainView.swift               # 主视图
    ├── Sidebar/                     # 侧边栏
    ├── Detail/                      # 详情视图
    ├── Terminal/                    # 终端视图
    └── Components/                  # 通用组件
```

## 系统要求

- macOS 13.0 或更高版本
- Xcode 14.0 或更高版本
