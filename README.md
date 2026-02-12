# ai-settings

集中管理 AI 编程助手的工作流和技能文件（OpenSpec、SpecKit、OPSX）。只需克隆一次本仓库，通过符号链接将相关目录映射到各个项目中，避免在每个项目中重复存放相同的文件。

## 解决的问题

OpenSpec、SpecKit 等工具会在每个项目中生成配置目录（`.claude/`、`.cursor/`、`.windsurf/`、`.opencode/`、`.trae/`、`.github/`、`.specify/`、`openspec/`），导致：

- 大量完全相同的文件在各仓库中重复存在
- 上游更新时各项目版本不一致
- 增加不必要的 diff 噪音和 `.gitignore` 负担

## 包含内容

| 目录          | 工具 / 编辑器          | 内容                            |
|---------------|------------------------|--------------------------------|
| `.claude/`    | Claude Code (CLI)      | Skills + 斜杠命令              |
| `.cursor/`    | Cursor                 | Skills + 命令                  |
| `.windsurf/`  | Windsurf               | Skills + 工作流                |
| `.trae/`      | Trae                   | Skills                         |
| `.opencode/`  | OpenCode               | Skills + 命令                  |
| `.github/`    | GitHub Copilot         | Skills + Prompt 文件           |
| `.specify/`   | SpecKit                | 模板、脚本、项目规范           |
| `openspec/`   | OpenSpec               | 配置文件 (config.yaml)         |

## 脚本工具

| 脚本          | 用途                                    | 运行位置              |
|---------------|----------------------------------------|-----------------------|
| `install.sh`  | 安装/升级 OpenSpec 和 SpecKit 工具      | `~/ai-settings/`      |
| `refresh.sh`  | 刷新/更新 AI 工具配置文件               | `~/ai-settings/`      |
| `setup.sh`    | 在项目中创建符号链接                    | 任意项目目录          |

## 快速开始

### 工作流程概览

```bash
# 1️⃣ 克隆本仓库（一次性）
git clone git@gitlab.baofoo.net:payful-commons/ai-settings.git ~/ai-settings

# 2️⃣ 安装工具（一次性）
~/ai-settings/install.sh

# 3️⃣ 生成配置（一次性或更新时）
~/ai-settings/refresh.sh

# 4️⃣ 在项目中创建符号链接（每个项目一次）
cd /path/to/your-project
~/ai-settings/setup.sh

# 5️⃣ 后续更新（需要时）
cd ~/ai-settings
git pull                      # 拉取最新配置
./install.sh --upgrade        # 升级工具
./refresh.sh                  # 刷新配置
```

### 1. 将本仓库克隆到一个固定位置

```bash
# macOS / Linux
git clone git@gitlab.baofoo.net:payful-commons/ai-settings.git ~/ai-settings

# Windows (Git Bash / PowerShell)
git clone git@gitlab.baofoo.net:payful-commons/ai-settings.git C:\Users\%USERNAME%\ai-settings
```

### 2. 使用安装脚本（推荐）

本仓库提供了一键安装脚本，在**你的项目目录**下运行即可自动创建符号链接并更新 `.gitignore`。

#### macOS / Linux

```bash
cd /path/to/your-project
~/ai-settings/setup.sh
```

默认链接所有目录。如果只需要部分工具，可以指定目录名：

```bash
# 只链接 Claude Code 和 Cursor
~/ai-settings/setup.sh .claude .cursor

# 强制替换已存在的目录为符号链接
~/ai-settings/setup.sh --force
```

#### Windows (PowerShell)

> **注意：** Windows 创建符号链接需要**管理员权限**或开启[开发者模式](https://learn.microsoft.com/zh-cn/windows/apps/get-started/enable-your-device-for-development)（设置 -> 系统 -> 高级 -> 开发者模式）。

```powershell
cd C:\path\to\your-project
C:\Users\$env:USERNAME\ai-settings\setup.ps1
```

指定部分目录：

```powershell
C:\Users\$env:USERNAME\ai-settings\setup.ps1 -Dirs .claude,.cursor
```

强制替换已存在的目录为符号链接：

```powershell
C:\Users\$env:USERNAME\ai-settings\setup.ps1 -Force
```

### 3. 手动安装（可选）

如果不想使用脚本，也可以手动创建符号链接。

<details>
<summary>macOS / Linux 手动命令</summary>

```bash
ln -s ~/ai-settings/.claude .claude
ln -s ~/ai-settings/.cursor .cursor
ln -s ~/ai-settings/.windsurf .windsurf
ln -s ~/ai-settings/.trae .trae
ln -s ~/ai-settings/.opencode .opencode
ln -s ~/ai-settings/.github .github
ln -s ~/ai-settings/.specify .specify
ln -s ~/ai-settings/openspec openspec
```

</details>

<details>
<summary>Windows PowerShell 手动命令</summary>

```powershell
New-Item -ItemType SymbolicLink -Path .claude   -Target C:\Users\$env:USERNAME\ai-settings\.claude
New-Item -ItemType SymbolicLink -Path .cursor   -Target C:\Users\$env:USERNAME\ai-settings\.cursor
New-Item -ItemType SymbolicLink -Path .windsurf -Target C:\Users\$env:USERNAME\ai-settings\.windsurf
New-Item -ItemType SymbolicLink -Path .trae     -Target C:\Users\$env:USERNAME\ai-settings\.trae
New-Item -ItemType SymbolicLink -Path .opencode -Target C:\Users\$env:USERNAME\ai-settings\.opencode
New-Item -ItemType SymbolicLink -Path .github   -Target C:\Users\$env:USERNAME\ai-settings\.github
New-Item -ItemType SymbolicLink -Path .specify  -Target C:\Users\$env:USERNAME\ai-settings\.specify
New-Item -ItemType SymbolicLink -Path openspec  -Target C:\Users\$env:USERNAME\ai-settings\openspec
```

</details>

<details>
<summary>Windows CMD 手动命令（以管理员身份运行）</summary>

```cmd
mklink /D .claude   C:\Users\%USERNAME%\ai-settings\.claude
mklink /D .cursor   C:\Users\%USERNAME%\ai-settings\.cursor
mklink /D .windsurf C:\Users\%USERNAME%\ai-settings\.windsurf
mklink /D .trae     C:\Users\%USERNAME%\ai-settings\.trae
mklink /D .opencode C:\Users\%USERNAME%\ai-settings\.opencode
mklink /D .github   C:\Users\%USERNAME%\ai-settings\.github
mklink /D .specify  C:\Users\%USERNAME%\ai-settings\.specify
mklink /D openspec  C:\Users\%USERNAME%\ai-settings\openspec
```

</details>

手动安装后，请记得将已链接的目录添加到项目的 `.gitignore` 中：

```gitignore
# AI settings（符号链接自 ai-settings 仓库）
.claude/
.cursor/
.windsurf/
.trae/
.opencode/
.specify/
openspec/
# .github/ — 仅当项目没有自己的 .github 目录时才添加
```

## 工具安装

### 安装 OpenSpec 和 SpecKit

本仓库提供了自动化安装脚本，可一键安装或升级 OpenSpec 和 SpecKit 工具。

#### 基本用法

```bash
# 安装缺失的工具
~/ai-settings/install.sh

# 升级已安装的工具到最新版本
~/ai-settings/install.sh --upgrade

# 只检查安装状态，不安装
~/ai-settings/install.sh --check

# 强制重新安装所有工具
~/ai-settings/install.sh --force
```

#### 安装内容

- **OpenSpec** (`@openspec/cli`): 通过 npm 全局安装
- **SpecKit** (`specify-cli`): 通过 uv 从 GitHub 安装

脚本会自动：
1. 检查 Node.js、npm 是否已安装（OpenSpec 依赖）
2. 检查 uv 是否已安装（SpecKit 依赖）
3. 如果 uv 未安装，会提示是否自动安装
4. 安装或升级指定的工具

## 配置刷新

### 使用 refresh.sh 批量更新配置

安装工具后，使用 `refresh.sh` 脚本可以自动为所有 AI 工具生成或更新配置文件。

#### 基本用法

```bash
# 刷新所有工具配置（openspec + specify）
~/ai-settings/refresh.sh

# 只刷新指定工具
~/ai-settings/refresh.sh --tools openspec
~/ai-settings/refresh.sh --tools specify

# 显示要执行的命令，不实际运行
~/ai-settings/refresh.sh --manual

# 刷新后自动提交到 git
~/ai-settings/refresh.sh --commit
```

#### 刷新内容

- **OpenSpec**: 交互式选择要配置的 AI 工具（支持多选）
- **SpecKit**: 自动为以下工具生成配置：
  - Claude Code
  - Cursor
  - OpenCode
  - Windsurf
  - GitHub Copilot

脚本会自动：
1. 运行 `openspec init` (需要手动选择工具)
2. 运行 `specify init` 多次（每个 AI 工具一次，完全自动化）
3. 显示修改的文件
4. 询问是否提交更改到 git

> **提示**: 首次使用时，建议先运行 `install.sh` 安装工具，然后运行 `refresh.sh` 生成配置。

## 更新

### 更新本仓库

上游文件更新后，只需拉取一次，所有通过符号链接关联的项目会自动获得最新版本：

```bash
cd ~/ai-settings   # 或你的克隆位置
git pull
```

### 更新工具和配置

如果 OpenSpec 或 SpecKit 工具本身有更新：

```bash
cd ~/ai-settings

# 1. 升级工具到最新版本
./install.sh --upgrade

# 2. 重新生成配置文件
./refresh.sh

# 3. 提交更改
git add -A
git commit -m "chore: Update tools and configurations"
git push
```

## 按需使用

不需要链接所有目录，只链接你实际使用的编辑器和工具即可。例如只使用 Claude Code 和 Cursor：

```bash
~/ai-settings/setup.sh .claude .cursor
```

## 自定义 OpenSpec 配置

`openspec/config.yaml` 包含项目级别的配置（schema、context、rules）。如果需要针对特定项目进行定制，请复制文件而非使用符号链接：

```bash
mkdir -p openspec
cp ~/ai-settings/openspec/config.yaml openspec/config.yaml
```

## 注意事项

- **`.github/` 目录冲突：** 如果项目已有 `.github/` 目录（CI 工作流、Issue 模板等），请只链接子目录（如 `.github/skills/` 和 `.github/prompts/`），不要链接整个 `.github/`。
- **Windows 符号链接权限：** 需要管理员权限或开启开发者模式（设置 -> 系统 -> 高级 -> 开发者模式），否则创建符号链接会失败。
- **已有目录处理：**
  - 如果目标目录已存在且内容与本仓库相同，脚本会询问是否替换为符号链接
  - 如果目标目录内容与本仓库不同，脚本会显示差异并跳过
  - 使用 `-Force`（PowerShell）或 `--force`（Bash）参数可强制替换为符号链接
