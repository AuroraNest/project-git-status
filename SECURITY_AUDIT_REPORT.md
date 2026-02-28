# Git 安全审查报告

- 审查日期：2026-02-28
- 审查范围：`GitRepoManager` 项目中与 Git 命令执行、终端入口、路径处理、错误回显相关代码
- 审查方式：静态代码审查（未进行渗透测试）

## 结论

当前版本存在 **1 个高危、2 个中危、1 个低危** 风险项。按主人要求，本次仅修复功能问题，不改动以下安全风险代码。

## 发现项

### 1) 高危：`openInTerminal` 存在命令注入风险

- 位置：`GitRepoManager/ViewModels/MainViewModel.swift:412`
- 问题：`repository.path` 被直接拼接进 AppleScript 的 shell 命令字符串；若路径包含特殊字符，可能导致命令被打断并注入执行。
- 风险：可执行非预期命令，影响本机安全。
- 建议：改为严格参数化（避免字符串拼接），或使用安全的路径引用/转义方案。

### 2) 中危：内置终端允许任意 Git 参数执行，缺少风险拦截

- 位置：`GitRepoManager/ViewModels/TerminalViewModel.swift:39`、`GitRepoManager/Services/GitService.swift:622`
- 问题：用户输入直接传入执行，未限制危险参数组合（如通过 `-c` 注入高风险配置）。
- 风险：可被误操作或社工命令触发高风险行为。
- 建议：增加“安全模式”（命令白名单/危险参数二次确认/高危命令默认禁用）。

### 3) 中危：路径边界校验不足，存在符号链接越界风险

- 位置：`GitRepoManager/Services/ProjectScanner.swift:38`、`GitRepoManager/Services/GitService.swift:610`、`GitRepoManager/Views/Detail/FileListView.swift:181`
- 问题：文件扫描与文件读取流程缺少统一 realpath 边界校验。
- 风险：可通过符号链接访问仓库/项目根目录外文件。
- 建议：统一做 `resolvingSymlinksInPath` 后的根路径前缀校验，并在扫描时过滤可疑链接目录。

### 4) 低危：错误/命令回显可能泄露敏感信息

- 位置：`GitRepoManager/ViewModels/TerminalViewModel.swift:47`、`GitRepoManager/Views/Detail/RepositoryDetailView.swift:114`、`GitRepoManager/Views/Sidebar/RepositoryRowView.swift:77`、`GitRepoManager/Services/GitCommandRunner.swift:135`
- 问题：错误信息与命令文本可能包含 token、凭据 URL 等敏感数据。
- 风险：敏感信息在 UI/日志中暴露。
- 建议：增加统一脱敏（token/password/带凭据 URL）后再显示。

## 修复优先级建议

1. 先修复命令注入（高危）。
2. 再加终端命令风控与路径边界校验（中危）。
3. 最后完善敏感信息脱敏（低危）。

