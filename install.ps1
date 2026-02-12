#
# OpenSpec & SpecKit 安装/升级脚本 (Windows PowerShell)
#
# 用法:
#   .\install.ps1                   # 检查并安装缺失的工具
#   .\install.ps1 -Upgrade          # 升级已安装的工具到最新版本
#   .\install.ps1 -Check            # 只检查安装状态，不安装
#   .\install.ps1 -Force            # 强制重新安装
#

param(
    [switch]$Upgrade = $false,
    [switch]$Check = $false,
    [switch]$Force = $false,
    [switch]$Verbose = $false,
    [switch]$Help = $false
)

$ErrorActionPreference = "Stop"

# 配置
$OpenSpecPackage = "@openspec/cli"
$SpecKitRepo = "https://github.com/github/spec-kit.git"

# 显示帮助
if ($Help) {
    Write-Host @"
用法: .\install.ps1 [选项]

选项:
  -Upgrade          升级已安装的工具到最新版本
  -Check            只检查安装状态，不安装
  -Force            强制重新安装
  -Verbose          显示详细输出
  -Help             显示此帮助信息

模式说明:
  默认              安装缺失的工具
  -Upgrade          升级所有工具到最新版本
  -Check            只检查不安装
  -Force            强制重新安装所有工具

示例:
  .\install.ps1                # 安装缺失的工具
  .\install.ps1 -Upgrade       # 升级所有工具
  .\install.ps1 -Check         # 检查安装状态
"@
    exit 0
}

# 确定运行模式
$Mode = "install"
if ($Upgrade) { $Mode = "upgrade" }
if ($Check) { $Mode = "check" }
if ($Force) { $Mode = "force" }

# 辅助函数
function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ $Message" -ForegroundColor Blue
}

# 检查命令是否存在
function Test-CommandExists {
    param([string]$Command)
    $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

# 获取包版本
function Get-PackageVersion {
    param([string]$Command)

    if (Test-CommandExists $Command) {
        try {
            $version = & $Command --version 2>$null | Select-Object -First 1
            return $version
        }
        catch {
            return "unknown"
        }
    }
    else {
        return "not installed"
    }
}

# 获取 npm 包的最新版本
function Get-LatestVersion {
    param([string]$Package)

    try {
        $version = npm view $Package version 2>$null
        return $version
    }
    catch {
        return "unknown"
    }
}

# 检查 Node.js 和 npm
function Test-NodeJs {
    if (-not (Test-CommandExists "node")) {
        Write-Error "Node.js 未安装"
        Write-Host ""
        Write-Host "请先安装 Node.js:"
        Write-Host "  访问: https://nodejs.org/"
        Write-Host "  或使用: winget install OpenJS.NodeJS"
        return $false
    }

    if (-not (Test-CommandExists "npm")) {
        Write-Error "npm 未安装"
        Write-Host ""
        Write-Host "请安装 npm (通常随 Node.js 一起安装)"
        return $false
    }

    $nodeVersion = node --version
    $npmVersion = npm --version
    Write-Success "Node.js $nodeVersion"
    Write-Success "npm $npmVersion"
    return $true
}

# 检查 uv
function Test-Uv {
    if (-not (Test-CommandExists "uv")) {
        return $false
    }

    $uvVersion = uv --version
    Write-Success "uv $uvVersion"
    return $true
}

# 安装 uv
function Install-Uv {
    Write-Info "安装 uv..."
    Write-Host ""

    try {
        if ($script:Verbose) {
            powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
        }
        else {
            powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex" *>$null
        }

        # 刷新环境变量
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

        # 验证安装
        if (Test-CommandExists "uv") {
            $uvVersion = uv --version
            Write-Success "uv 已安装 ($uvVersion)"
            return $true
        }
        else {
            Write-Error "uv 安装失败"
            Write-Host ""
            Write-Host "请手动安装: powershell -ExecutionPolicy ByPass -c `"irm https://astral.sh/uv/install.ps1 | iex`""
            Write-Host "然后重新运行此脚本"
            return $false
        }
    }
    catch {
        Write-Error "uv 安装失败: $($_.Exception.Message)"
        return $false
    }
}

# 安装或升级 npm 包
function Install-Package {
    param(
        [string]$Package,
        [string]$Command,
        [string]$Action
    )

    Write-Host ""
    Write-Host "────────────────────────────────────────" -ForegroundColor Gray
    Write-Host "处理: $Package (npm)" -ForegroundColor Cyan
    Write-Host "────────────────────────────────────────" -ForegroundColor Gray

    $currentVersion = Get-PackageVersion -Command $Command
    $latestVersion = Get-LatestVersion -Package $Package

    Write-Host "当前版本: $currentVersion"
    Write-Host "最新版本: $latestVersion"
    Write-Host ""

    switch ($Action) {
        "install" {
            if ($currentVersion -eq "not installed") {
                Write-Info "安装 $Package..."
                try {
                    if ($script:Verbose) {
                        npm install -g $Package
                    }
                    else {
                        npm install -g $Package *>$null
                    }
                    Write-Success "已安装 $Package"
                }
                catch {
                    Write-Error "安装失败: $($_.Exception.Message)"
                }
            }
            else {
                Write-Success "$Command 已安装 (v$currentVersion)"
            }
        }
        "upgrade" {
            if ($currentVersion -eq "not installed") {
                Write-Warning "$Command 未安装，将进行安装"
                try {
                    if ($script:Verbose) {
                        npm install -g $Package
                    }
                    else {
                        npm install -g $Package *>$null
                    }
                    Write-Success "已安装 $Package"
                }
                catch {
                    Write-Error "安装失败: $($_.Exception.Message)"
                }
            }
            else {
                Write-Info "升级 $Package..."
                try {
                    if ($script:Verbose) {
                        npm install -g "$Package@latest"
                    }
                    else {
                        npm install -g "$Package@latest" *>$null
                    }
                    $newVersion = Get-PackageVersion -Command $Command
                    Write-Success "已升级到 v$newVersion"
                }
                catch {
                    Write-Error "升级失败: $($_.Exception.Message)"
                }
            }
        }
        "force" {
            Write-Info "强制重新安装 $Package..."
            try {
                if ($script:Verbose) {
                    npm uninstall -g $Package 2>$null
                    npm install -g $Package
                }
                else {
                    npm uninstall -g $Package *>$null
                    npm install -g $Package *>$null
                }
                $newVersion = Get-PackageVersion -Command $Command
                Write-Success "已重新安装 v$newVersion"
            }
            catch {
                Write-Error "重新安装失败: $($_.Exception.Message)"
            }
        }
    }
}

# 安装或升级 uv 工具
function Install-UvTool {
    param(
        [string]$ToolName,
        [string]$Repo,
        [string]$Command,
        [string]$Action
    )

    Write-Host ""
    Write-Host "────────────────────────────────────────" -ForegroundColor Gray
    Write-Host "处理: $ToolName (uv tool)" -ForegroundColor Cyan
    Write-Host "────────────────────────────────────────" -ForegroundColor Gray

    $currentVersion = Get-PackageVersion -Command $Command

    Write-Host "当前版本: $currentVersion"
    Write-Host ""

    switch ($Action) {
        "install" {
            if ($currentVersion -eq "not installed") {
                Write-Info "安装 $ToolName..."
                try {
                    if ($script:Verbose) {
                        uv tool install $ToolName --from "git+$Repo"
                    }
                    else {
                        uv tool install $ToolName --from "git+$Repo" *>$null
                    }
                    Write-Success "已安装 $ToolName"
                }
                catch {
                    Write-Error "安装失败: $($_.Exception.Message)"
                }
            }
            else {
                Write-Success "$Command 已安装 (v$currentVersion)"
            }
        }
        "upgrade" {
            if ($currentVersion -eq "not installed") {
                Write-Warning "$Command 未安装，将进行安装"
                try {
                    if ($script:Verbose) {
                        uv tool install $ToolName --from "git+$Repo"
                    }
                    else {
                        uv tool install $ToolName --from "git+$Repo" *>$null
                    }
                    Write-Success "已安装 $ToolName"
                }
                catch {
                    Write-Error "安装失败: $($_.Exception.Message)"
                }
            }
            else {
                Write-Info "升级 $ToolName..."
                try {
                    if ($script:Verbose) {
                        uv tool upgrade $ToolName
                    }
                    else {
                        uv tool upgrade $ToolName *>$null
                    }
                    $newVersion = Get-PackageVersion -Command $Command
                    Write-Success "已升级到 v$newVersion"
                }
                catch {
                    Write-Error "升级失败: $($_.Exception.Message)"
                }
            }
        }
        "force" {
            Write-Info "强制重新安装 $ToolName..."
            try {
                if ($script:Verbose) {
                    uv tool uninstall $ToolName 2>$null
                    uv tool install $ToolName --from "git+$Repo"
                }
                else {
                    uv tool uninstall $ToolName *>$null
                    uv tool install $ToolName --from "git+$Repo" *>$null
                }
                $newVersion = Get-PackageVersion -Command $Command
                Write-Success "已重新安装 v$newVersion"
            }
            catch {
                Write-Error "重新安装失败: $($_.Exception.Message)"
            }
        }
    }
}

# 主函数
function Main {
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  OpenSpec & SpecKit 安装脚本" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""

    # 检查依赖
    Write-Info "检查依赖..."

    # 检查 Node.js 和 npm (用于 openspec)
    if (-not (Test-NodeJs)) {
        exit 1
    }

    Write-Host ""

    # 检查 uv (用于 speckit)
    if (-not (Test-Uv)) {
        Write-Warning "uv 未安装 (SpecKit 需要 uv)"
        Write-Host ""

        if ($Mode -eq "check") {
            $script:SkipSpecKit = $true
        }
        else {
            $response = Read-Host "是否自动安装 uv？(Y/n)"
            if ($response -eq "n" -or $response -eq "N") {
                Write-Info "跳过 uv 安装，将不安装 SpecKit"
                $script:SkipSpecKit = $true
            }
            else {
                if (Install-Uv) {
                    $script:SkipSpecKit = $false
                }
                else {
                    $script:SkipSpecKit = $true
                }
            }
        }
    }
    else {
        $script:SkipSpecKit = $false
    }

    Write-Host ""
    Write-Info "检查工具状态..."

    # 获取当前版本
    $openspecVersion = Get-PackageVersion -Command "openspec"
    $speckitVersion = Get-PackageVersion -Command "specify"

    Write-Host "  openspec: $openspecVersion"
    Write-Host "  speckit:  $speckitVersion"

    # 根据模式执行操作
    switch ($Mode) {
        "check" {
            Write-Host ""
            Write-Info "检查模式 - 不执行安装操作"
            if ($openspecVersion -eq "not installed") {
                Write-Warning "openspec 未安装"
            }
            else {
                Write-Success "openspec 已安装 (v$openspecVersion)"
            }
            if ($speckitVersion -eq "not installed") {
                Write-Warning "specify 未安装"
            }
            else {
                Write-Success "specify 已安装 (v$speckitVersion)"
            }
        }
        "install" {
            Install-Package -Package $OpenSpecPackage -Command "openspec" -Action "install"
            if (-not $script:SkipSpecKit) {
                Install-UvTool -ToolName "specify-cli" -Repo $SpecKitRepo -Command "specify" -Action "install"
            }
        }
        "upgrade" {
            Install-Package -Package $OpenSpecPackage -Command "openspec" -Action "upgrade"
            if (-not $script:SkipSpecKit) {
                Install-UvTool -ToolName "specify-cli" -Repo $SpecKitRepo -Command "specify" -Action "upgrade"
            }
        }
        "force" {
            Install-Package -Package $OpenSpecPackage -Command "openspec" -Action "force"
            if (-not $script:SkipSpecKit) {
                Install-UvTool -ToolName "specify-cli" -Repo $SpecKitRepo -Command "specify" -Action "force"
            }
        }
    }

    Write-Host ""
    Write-Host "────────────────────────────────────────" -ForegroundColor Gray
    Write-Host "完成！" -ForegroundColor Green
    Write-Host "────────────────────────────────────────" -ForegroundColor Gray
    Write-Host ""

    # 显示最终状态
    if ($Mode -ne "check") {
        Write-Info "最终状态:"
        $finalOpenspec = Get-PackageVersion -Command "openspec"
        $finalSpeckit = Get-PackageVersion -Command "specify"
        Write-Host "  openspec: $finalOpenspec"
        Write-Host "  speckit:  $finalSpeckit"
        Write-Host ""
    }

    # 提示下一步
    if ($Mode -eq "install" -or $Mode -eq "force") {
        Write-Info "下一步:"
        Write-Host "  运行 'openspec init' 初始化配置"
        Write-Host "  运行 'specify init' 初始化配置"
        Write-Host "  或使用 '.\refresh.ps1' 批量初始化"
    }

    Write-Host ""
}

# 运行主函数
Main
