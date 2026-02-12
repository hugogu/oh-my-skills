#
# ai-settings 内容刷新脚本 (Windows PowerShell)
#
# 用法:
#   .\refresh.ps1                        # 交互模式，刷新所有工具
#   .\refresh.ps1 -Auto                  # 自动模式
#   .\refresh.ps1 -Tools openspec        # 只运行 openspec init
#   .\refresh.ps1 -Manual                # 手动模式，显示每个命令
#

param(
    [string]$Tools = "",
    [switch]$Commit = $false,
    [switch]$Manual = $false,
    [switch]$Verbose = $false,
    [switch]$Help = $false
)

$ErrorActionPreference = "Stop"

# 获取脚本所在目录
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# 支持的工具列表
$ToolsToRefresh = @("openspec", "specify")

# 目标 AI 工具/环境列表（按顺序）
$TargetToolsOrdered = @(
    "Claude Code",
    "Cursor",
    "OpenCode",
    "Trae",
    "Windsurf",
    "GitHub Copilot",
    "Specify"
)

# 工具名称到选项编号的映射
$ToolToNumber = @{
    "Claude Code" = "1"
    "Cursor" = "2"
    "OpenCode" = "3"
    "Trae" = "4"
    "Windsurf" = "5"
    "GitHub Copilot" = "6"
    "Specify" = "7"
}

# 显示帮助
if ($Help) {
    Write-Host @"
用法: .\refresh.ps1 [选项]

选项:
  -Tools <name>    只运行指定工具 (openspec 或 specify)
  -Commit          自动提交更改到 git
  -Manual          手动模式（仅显示命令）
  -Verbose         显示详细输出
  -Help            显示此帮助信息

模式说明:
  默认              交互模式，运行命令并手动选择工具
  -Manual           仅显示需要运行的命令和选择的工具

注意:
  openspec init 和 specify init 允许一次选择多个工具
  脚本会运行命令一次，你需要选择所有需要的工具

示例:
  .\refresh.ps1                    # 交互模式
  .\refresh.ps1 -Manual            # 显示命令列表
  .\refresh.ps1 -Tools openspec    # 只运行 openspec init
  .\refresh.ps1 -Commit            # 交互模式并提交
"@
    exit 0
}

# 确定运行模式
$Mode = "interactive"
if ($Manual) { $Mode = "manual" }

# 检查命令是否存在
function Test-Command {
    param([string]$CommandName)

    $command = Get-Command $CommandName -ErrorAction SilentlyContinue
    if (-not $command) {
        Write-Host "[错误] 命令 '$CommandName' 未找到，请先安装" -ForegroundColor Red
        return $false
    }
    return $true
}

# 主逻辑
function Main {
    Write-Host ""
    Write-Host "=== ai-settings 内容刷新脚本 ===" -ForegroundColor Cyan
    Write-Host "仓库目录: $ScriptDir"
    Write-Host "运行模式: $Mode"
    Write-Host ""

    # 切换到仓库目录
    Set-Location $ScriptDir

    # 检查是否是 git 仓库
    if (-not (Test-Path ".git")) {
        Write-Host "[错误] 当前目录不是 git 仓库" -ForegroundColor Red
        exit 1
    }

    # 检查工作目录是否干净
    $gitStatus = & git status --porcelain
    if ($gitStatus) {
        Write-Host "[警告] 工作目录有未提交的更改" -ForegroundColor Yellow
        if ($Mode -ne "auto") {
            $response = Read-Host "是否继续？(y/N)"
            if ($response -ne "y" -and $response -ne "Y") {
                Write-Host "已取消" -ForegroundColor Yellow
                exit 0
            }
        }
    }

    # 确定要运行的工具
    $toolsToRun = @()
    if ($Tools -ne "") {
        $toolsToRun = @($Tools)
    } else {
        $toolsToRun = $ToolsToRefresh
    }

    # 对每个工具运行初始化
    foreach ($tool in $toolsToRun) {
        Write-Host ""
        Write-Host "────────────────────────────────────────" -ForegroundColor Gray
        Write-Host "运行工具: $tool init" -ForegroundColor Cyan
        Write-Host "────────────────────────────────────────" -ForegroundColor Gray

        # 检查命令是否存在
        if (-not (Test-Command $tool)) {
            Write-Host "[跳过] $tool 命令不可用" -ForegroundColor Yellow
            continue
        }

        $cmd = "$tool init"

        # 显示要选择的工具列表
        Write-Host "需要选择的工具:" -ForegroundColor Cyan
        foreach ($toolName in $TargetToolsOrdered) {
            Write-Host "  ✓ $toolName" -ForegroundColor Green
        }
        Write-Host ""

        # 根据模式运行命令
        if ($Mode -eq "manual") {
            Write-Host "[手动模式] 请运行以下命令:" -ForegroundColor Yellow
            Write-Host "  $cmd" -ForegroundColor White
            Write-Host ""
            Write-Host "在提示时选择以下工具:" -ForegroundColor Yellow
            foreach ($toolName in $TargetToolsOrdered) {
                Write-Host "  - $toolName" -ForegroundColor White
            }
        }
        else {
            # 交互模式 - 直接运行
            Write-Host "[交互模式] 请在提示时选择所有需要的工具" -ForegroundColor Cyan
            Write-Host ""

            try {
                & $cmd.Split()[0] $cmd.Split()[1..999]
                if ($LASTEXITCODE -eq 0 -or $null -eq $LASTEXITCODE) {
                    Write-Host ""
                    Write-Host "[完成] $tool init" -ForegroundColor Green
                } else {
                    Write-Host ""
                    Write-Host "[警告] 执行失败或用户取消" -ForegroundColor Yellow
                }
            }
            catch {
                Write-Host ""
                Write-Host "[警告] 执行失败: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
    }

    Write-Host ""
    Write-Host "────────────────────────────────────────" -ForegroundColor Gray
    Write-Host "刷新完成！" -ForegroundColor Green
    Write-Host "────────────────────────────────────────" -ForegroundColor Gray
    Write-Host ""

    # 显示更改的文件
    $gitStatus = & git status --porcelain
    if (-not $gitStatus) {
        Write-Host "[信息] 没有文件被修改" -ForegroundColor Gray
    } else {
        Write-Host "已修改的文件:" -ForegroundColor Cyan
        & git status --short
        Write-Host ""

        # 自动提交或询问
        if ($Commit) {
            Write-Host "[自动提交] 提交更改到 git..." -ForegroundColor Cyan
            $commitMessage = @"
chore: Refresh AI tool configurations

Updated configurations for all AI tools using:
$(foreach ($t in $toolsToRun) { "- $t init" })

Auto-generated by refresh.ps1
"@
            & git add -A
            & git commit -m $commitMessage
            if ($LASTEXITCODE -eq 0) {
                Write-Host "[完成] 更改已提交" -ForegroundColor Green
            } else {
                Write-Host "[警告] 提交失败" -ForegroundColor Yellow
            }
        } else {
            $response = Read-Host "是否提交更改到 git？(y/N)"
            if ($response -eq "y" -or $response -eq "Y") {
                $commitMessage = @"
chore: Refresh AI tool configurations

Updated configurations for all AI tools using:
$(foreach ($t in $toolsToRun) { "- $t init" })

Generated by refresh.ps1
"@
                & git add -A
                & git commit -m $commitMessage
                Write-Host "[完成] 更改已提交" -ForegroundColor Green
            } else {
                Write-Host "[跳过] 未提交更改" -ForegroundColor Yellow
            }
        }
    }

    Write-Host ""
    Write-Host "完成！" -ForegroundColor Green
}

# 运行主函数
Main
