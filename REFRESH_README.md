# AI Settings Refresh Scripts

自动刷新所有 AI 工具配置的脚本。

## 概述

这些脚本帮助你自动运行 `openspec init` 和 `specify init` 来更新 ai-settings 仓库中的所有工具配置。

## 使用方法

### Bash (Linux/macOS/WSL)

```bash
# 交互模式（默认）- 每个工具需要手动选择选项
./refresh.sh

# 自动模式 - 使用 expect 自动化（需要安装 expect）
./refresh.sh --auto

# 手动模式 - 仅显示需要运行的命令
./refresh.sh --manual

# 只刷新特定工具
./refresh.sh --tools openspec

# 自动模式并提交更改
./refresh.sh --auto --commit
```

### PowerShell (Windows)

```powershell
# 交互模式（默认）
.\refresh.ps1

# 自动模式
.\refresh.ps1 -Auto

# 手动模式
.\refresh.ps1 -Manual

# 只刷新特定工具
.\refresh.ps1 -Tools openspec

# 自动模式并提交更改
.\refresh.ps1 -Auto -Commit
```

## 运行模式

### 1. 交互模式（默认）

- 运行每个 `openspec init` 和 `specify init` 命令
- 脚本会提示你需要选择的选项编号
- 每完成一个工具会询问是否继续
- 适合第一次使用或需要确认的情况

### 2. 自动模式 (`--auto` / `-Auto`)

- 自动发送选项编号到交互命令
- Bash: 需要安装 `expect` 命令
- PowerShell: 使用进程重定向自动化
- 适合批量更新

### 3. 手动模式 (`--manual` / `-Manual`)

- 只显示需要运行的命令和选项编号
- 不实际执行命令
- 适合查看或手动执行

## 工具列表

脚本会为以下工具运行初始化：

1. **Claude Code** (.claude) - 选项 1
2. **Cursor** (.cursor) - 选项 2
3. **OpenCode** (.opencode) - 选项 3
4. **Trae** (.trae) - 选项 4
5. **Windsurf** (.windsurf) - 选项 5
6. **GitHub Copilot** (.github) - 选项 6
7. **Specify** (.specify) - 选项 7

## 选项编号配置

如果实际命令的选项编号不同，请修改脚本中的映射：

**Bash (refresh.sh):**
```bash
declare -A TOOL_TO_NUMBER=(
    ["Claude Code"]="1"
    ["Cursor"]="2"
    # ... 等等
)
```

**PowerShell (refresh.ps1):**
```powershell
$ToolToNumber = @{
    "Claude Code" = "1"
    "Cursor" = "2"
    # ... 等等
}
```

## 依赖

### Bash 自动模式

需要安装 `expect`:

```bash
# Ubuntu/Debian
sudo apt-get install expect

# macOS
brew install expect
```

### PowerShell

无需额外依赖，使用内置的进程重定向功能。

## 示例工作流

### 完整更新流程

```bash
# 1. 确保在 ai-settings 仓库目录
cd ~/ai-settings

# 2. 运行刷新脚本（交互模式）
./refresh.sh

# 3. 对每个工具，按照提示选择选项编号
#    例如：openspec init 提示 "Select target tool"
#    输入对应的编号（1=Claude Code, 2=Cursor, 等等）

# 4. 查看更改
git status

# 5. 提交更改
git add -A
git commit -m "chore: Refresh AI tool configurations"
git push
```

### 快速自动更新

```bash
# 自动运行并提交（需要 expect）
./refresh.sh --auto --commit
git push
```

## 故障排除

### 1. expect 命令未找到

**问题:** `[错误] auto 模式需要 expect 命令`

**解决:** 安装 expect 或使用交互/手动模式

### 2. 命令未找到

**问题:** `[错误] 命令 'openspec' 未找到`

**解决:** 确保 `openspec` 或 `specify` 命令已安装并在 PATH 中

### 3. 选项编号不匹配

**问题:** 自动模式选择了错误的选项

**解决:** 更新脚本中的 `TOOL_TO_NUMBER` 映射

## 自定义

### 添加新工具

1. 在 `TARGET_TOOLS_ORDERED` 数组中添加工具名
2. 在 `TOOL_TO_NUMBER` 映射中添加对应的选项编号
3. 确保对应的目录（如 `.newtool`）存在于 ai-settings 仓库中

### 修改刷新工具列表

编辑 `TOOLS_TO_REFRESH` 数组：

```bash
# 只运行 openspec
TOOLS_TO_REFRESH=("openspec")

# 添加自定义工具
TOOLS_TO_REFRESH=("openspec" "specify" "custom-tool")
```

## 相关脚本

- `setup.sh` / `setup.ps1` - 在项目中设置 ai-settings 符号链接
- `refresh.sh` / `refresh.ps1` - 刷新 ai-settings 仓库内容（本文档）

## 注意事项

1. **运行位置:** 必须在 ai-settings 仓库根目录运行
2. **Git 工作目录:** 如有未提交更改会提示确认
3. **自动提交:** 使用 `--commit` 标志会自动提交所有更改
4. **选项编号:** 确保 `TOOL_TO_NUMBER` 映射与实际命令选项一致
