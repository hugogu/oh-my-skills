# Installation Scripts

自动安装和升级 OpenSpec 和 SpecKit 的脚本。

## 概述

这些脚本帮助你:
- ✅ 检查 OpenSpec 和 SpecKit 是否已安装
- ✅ 自动安装缺失的工具
- ✅ 升级已安装的工具到最新版本
- ✅ 强制重新安装工具
- ✅ 检查 Node.js 和 npm 依赖

## 前提条件

### 必需
- **Node.js** (v14 或更高版本) - 用于安装 OpenSpec
- **npm** (通常随 Node.js 一起安装) - 用于安装 OpenSpec
- **uv** (Python 包管理器) - 用于安装 SpecKit

### 安装 Node.js

**Linux/WSL:**
```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install nodejs npm

# 或使用 nvm (推荐)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
nvm install node
```

**macOS:**
```bash
# 使用 Homebrew
brew install node
```

**Windows:**
```powershell
# 使用 winget
winget install OpenJS.NodeJS

# 或从官网下载
# https://nodejs.org/
```

### 安装 uv

**Linux/WSL/macOS:**
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

**Windows:**
```powershell
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"

# 或使用 winget
winget install astral-sh.uv
```

## 使用方法

### Bash (Linux/macOS/WSL)

#### 基本用法
```bash
# 检查并安装缺失的工具（默认模式）
./install.sh

# 检查安装状态（不安装）
./install.sh --check

# 升级已安装的工具到最新版本
./install.sh --upgrade

# 强制重新安装所有工具
./install.sh --force

# 显示详细输出
./install.sh --verbose
```

### PowerShell (Windows)

#### 基本用法
```powershell
# 检查并安装缺失的工具（默认模式）
.\install.ps1

# 检查安装状态（不安装）
.\install.ps1 -Check

# 升级已安装的工具到最新版本
.\install.ps1 -Upgrade

# 强制重新安装所有工具
.\install.ps1 -Force

# 显示详细输出
.\install.ps1 -Verbose
```

## 运行模式

### 1. Install（默认）- 安装缺失的工具

```bash
./install.sh
# or
.\install.ps1
```

**行为:**
- 检查 openspec 和 speckit 是否已安装
- 只安装未安装的工具
- 已安装的工具跳过
- 显示当前版本和最新版本

**输出示例:**
```
═══════════════════════════════════════════════════
  OpenSpec & SpecKit 安装脚本
═══════════════════════════════════════════════════

ℹ 检查依赖...
✓ Node.js v18.17.0
✓ npm 9.6.7

ℹ 检查工具状态...
  openspec: not installed
  speckit:  1.2.3

────────────────────────────────────────
处理: @openspec/cli
────────────────────────────────────────
当前版本: not installed
最新版本: 2.1.0

ℹ 安装 @openspec/cli...
✓ 已安装 @openspec/cli

────────────────────────────────────────
处理: @speckit/cli
────────────────────────────────────────
当前版本: 1.2.3
最新版本: 1.2.5

✓ speckit 已安装 (v1.2.3)
```

### 2. Check - 仅检查状态

```bash
./install.sh --check
# or
.\install.ps1 -Check
```

**行为:**
- 检查依赖（Node.js, npm）
- 显示 openspec 和 speckit 的安装状态
- 不执行任何安装或升级操作

### 3. Upgrade - 升级到最新版本

```bash
./install.sh --upgrade
# or
.\install.ps1 -Upgrade
```

**行为:**
- 检查所有工具
- 升级已安装的工具到最新版本
- 安装未安装的工具
- 显示升级前后的版本

**输出示例:**
```
────────────────────────────────────────
处理: @openspec/cli
────────────────────────────────────────
当前版本: 2.0.5
最新版本: 2.1.0

ℹ 升级 @openspec/cli...
✓ 已升级到 v2.1.0
```

### 4. Force - 强制重新安装

```bash
./install.sh --force
# or
.\install.ps1 -Force
```

**行为:**
- 卸载已安装的工具
- 重新安装最新版本
- 适用于修复损坏的安装

## 安装的包

脚本会安装以下工具:

| 工具 | 安装方式 | 命令 | 用途 |
|------|----------|------|------|
| OpenSpec | npm (`@openspec/cli`) | `openspec` | OpenSpec CLI 工具 |
| SpecKit | uv (`specify-cli` from GitHub) | `specify` | SpecKit CLI 工具 |

**注意:**
- OpenSpec 通过 npm 全局安装
- SpecKit 通过 uv tool 从 GitHub 仓库安装

## 配置

脚本配置位于文件顶部:

**Bash (install.sh):**
```bash
# OpenSpec (npm 包)
OPENSPEC_PACKAGE="@openspec/cli"

# SpecKit (uv tool from GitHub)
SPECKIT_REPO="https://github.com/github/spec-kit.git"
```

**PowerShell (install.ps1):**
```powershell
# OpenSpec (npm 包)
$OpenSpecPackage = "@openspec/cli"

# SpecKit (uv tool from GitHub)
$SpecKitRepo = "https://github.com/github/spec-kit.git"
```

## 故障排除

### 1. Node.js 或 uv 未安装

**问题:** `✗ Node.js 未安装` 或 `✗ uv 未安装`

**解决:**
- 安装 Node.js 和 uv (见上方"前提条件"部分)
- 确保 `node`, `npm`, 和 `uv` 在 PATH 中
- 如果 uv 未安装，脚本会跳过 SpecKit 安装

### 2. 权限错误

**Linux/macOS:**
```bash
# 如果遇到权限错误，使用 nvm 或修改 npm 全局目录
mkdir ~/.npm-global
npm config set prefix '~/.npm-global'
export PATH=~/.npm-global/bin:$PATH

# 或使用 sudo (不推荐)
sudo ./install.sh
```

**Windows:**
```powershell
# 以管理员身份运行 PowerShell
# 右键点击 PowerShell -> "以管理员身份运行"
```

### 3. 网络问题

**问题:** npm 下载失败

**解决:**
```bash
# 使用 npm 镜像（中国大陆）
npm config set registry https://registry.npmmirror.com

# 或使用代理
npm config set proxy http://proxy.example.com:8080
```

### 4. 版本获取失败

**问题:** `当前版本: unknown` 或 `最新版本: unknown`

**解决:**
- 检查命令是否正确安装: `which openspec` / `which speckit`
- 检查命令是否有 `--version` 选项
- 检查网络连接（获取最新版本需要访问 npm registry）

## 工作流示例

### 首次安装

```bash
# 1. 检查是否需要安装
./install.sh --check

# 2. 安装缺失的工具
./install.sh

# 3. 验证安装
openspec --version
speckit --version

# 4. 初始化配置
./refresh.sh
```

### 定期更新

```bash
# 1. 检查当前版本
./install.sh --check

# 2. 升级到最新版本
./install.sh --upgrade

# 3. 刷新配置
./refresh.sh
```

### 修复损坏的安装

```bash
# 强制重新安装
./install.sh --force

# 刷新配置
./refresh.sh
```

## 与其他脚本配合使用

### 完整设置流程

```bash
# 1. 安装工具
./install.sh

# 2. 初始化配置
./refresh.sh

# 3. 在项目中设置符号链接
cd /path/to/your/project
/path/to/ai-settings/setup.sh
```

### 自动化脚本

创建一个 `bootstrap.sh`:

```bash
#!/bin/bash
# bootstrap.sh - 完整设置脚本

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "1. 安装 OpenSpec 和 SpecKit..."
"$SCRIPT_DIR/install.sh"

echo ""
echo "2. 刷新配置..."
"$SCRIPT_DIR/refresh.sh"

echo ""
echo "3. 设置符号链接..."
"$SCRIPT_DIR/setup.sh"

echo ""
echo "完成！所有工具已就绪。"
```

## 相关脚本

- `install.sh` / `install.ps1` - 安装/升级 OpenSpec 和 SpecKit（本文档）
- `refresh.sh` / `refresh.ps1` - 刷新 AI 工具配置
- `setup.sh` / `setup.ps1` - 在项目中设置符号链接

## 注意事项

1. **全局安装:** 脚本使用 `npm install -g` 全局安装包
2. **版本检查:** 需要网络连接以获取最新版本信息
3. **权限:** 可能需要管理员权限（Windows）或 sudo（Linux/macOS）
4. **Node.js 版本:** 建议使用 Node.js v14 或更高版本

## 卸载

如需卸载工具:

**Linux/WSL/macOS:**
```bash
# 卸载 openspec
npm uninstall -g @openspec/cli

# 卸载 speckit
uv tool uninstall specify-cli
```

**Windows PowerShell:**
```powershell
# 卸载 openspec
npm uninstall -g @openspec/cli

# 卸载 speckit
uv tool uninstall specify-cli
```
