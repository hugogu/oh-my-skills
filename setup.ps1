#
# ai-settings 快速安装脚本 (Windows PowerShell)
#
# 用法:
#   C:\Users\<用户名>\ai-settings\setup.ps1                     # 链接所有目录
#   C:\Users\<用户名>\ai-settings\setup.ps1 -Dirs .claude,.cursor  # 只链接指定目录
#
# 注意: 需要管理员权限或已开启开发者模式
#

param(
    [string]$Dirs = "",
    [switch]$Force = $false
)

$ErrorActionPreference = "Stop"

# 获取脚本自身所在目录（即 ai-settings 仓库根目录）
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# 可链接的所有目录
# 注意：某些目录会特殊处理，只链接部分子目录：
#   - .claude: 只链接 skills, commands (保留本地的 settings.local.json 等文件)
#   - .cursor: 只链接 skills, commands (保留本地的配置文件)
#   - .opencode: 只链接 skills, command (保留本地的配置文件)
#   - .trae: 只链接 skills (保留本地的配置文件)
#   - .windsurf: 只链接 skills, workflows (保留本地的 rules 目录)
#   - .github: 只链接 agents, prompts, skills (保留本地的 workflows, issue templates 等)
#   - .specify: 只链接 scripts, templates (保留本地的 memory, agent-context 目录)
$AllDirs = @(".claude", ".cursor", ".windsurf", ".trae", ".opencode", ".github", ".specify")

# 本地配置文件列表（这些文件在差异比较时会被忽略，且在符号链接创建后会被保留）
# 注意：对于子目录链接的目录，配置文件位于父目录本身，不在符号链接中
$LocalConfigFiles = @(
    ".claude/settings.local.json",
    ".cursor/settings.local.json",
    ".windsurf/settings.local.json"
)

# 如果传入了参数，只链接指定的目录；否则链接全部
if ($Dirs -ne "") {
    $TargetDirs = $Dirs -split ","
} else {
    $TargetDirs = $AllDirs
}

# 检查是否有创建符号链接的权限
function Test-SymlinkPermission {
    $testLink = Join-Path $env:TEMP "ai-settings-symlink-test"
    $testTarget = $ScriptDir
    try {
        if (Test-Path $testLink) { Remove-Item $testLink -Force }
        New-Item -ItemType SymbolicLink -Path $testLink -Target $testTarget -ErrorAction Stop | Out-Null
        Remove-Item $testLink -Force
        return $true
    } catch {
        return $false
    }
}

# 比较两个目录是否内容相同
function Compare-Directories {
    param(
        [string]$Path1,
        [string]$Path2
    )

    $files1 = Get-ChildItem -Path $Path1 -Recurse -File | ForEach-Object {
        @{
            RelativePath = $_.FullName.Substring($Path1.Length).TrimStart('\')
            Hash = (Get-FileHash -Path $_.FullName -Algorithm MD5).Hash
        }
    } | Sort-Object -Property RelativePath

    $files2 = Get-ChildItem -Path $Path2 -Recurse -File | ForEach-Object {
        @{
            RelativePath = $_.FullName.Substring($Path2.Length).TrimStart('\')
            Hash = (Get-FileHash -Path $_.FullName -Algorithm MD5).Hash
        }
    } | Sort-Object -Property RelativePath

    if ($files1.Count -ne $files2.Count) {
        return $false
    }

    for ($i = 0; $i -lt $files1.Count; $i++) {
        if ($files1[$i].RelativePath -ne $files2[$i].RelativePath -or
            $files1[$i].Hash -ne $files2[$i].Hash) {
            return $false
        }
    }

    return $true
}

# 检查文件是否应该被忽略（本地配置文件）
function Should-IgnoreFile {
    param(
        [string]$RelativePath,
        [string]$DirName
    )

    $fullPath = "$DirName/$RelativePath".Replace('\', '/')
    foreach ($pattern in $script:LocalConfigFiles) {
        if ($fullPath -like $pattern -or $fullPath -eq $pattern) {
            return $true
        }
    }
    return $false
}

# 获取目录差异详情
function Get-DirectoryDiff {
    param(
        [string]$Path1,
        [string]$Path2,
        [string]$DirName
    )

    $files1 = Get-ChildItem -Path $Path1 -Recurse -File | ForEach-Object {
        @{
            RelativePath = $_.FullName.Substring($Path1.Length).TrimStart('\')
            Hash = (Get-FileHash -Path $_.FullName -Algorithm MD5).Hash
        }
    } | Group-Object -Property RelativePath -AsHashTable

    $files2 = Get-ChildItem -Path $Path2 -Recurse -File | ForEach-Object {
        @{
            RelativePath = $_.FullName.Substring($Path2.Length).TrimStart('\')
            Hash = (Get-FileHash -Path $_.FullName -Algorithm MD5).Hash
        }
    } | Group-Object -Property RelativePath -AsHashTable

    $allFiles = ($files1.Keys + $files2.Keys) | Sort-Object -Unique

    $diff = @{
        OnlyInLocal = @()
        OnlyInSource = @()
        Different = @()
        Ignored = @()
    }

    foreach ($file in $allFiles) {
        # 检查是否应该忽略此文件
        if (Should-IgnoreFile -RelativePath $file -DirName $DirName) {
            $diff.Ignored += $file
            continue
        }

        if (-not $files1.ContainsKey($file)) {
            $diff.OnlyInLocal += $file
        } elseif (-not $files2.ContainsKey($file)) {
            $diff.OnlyInSource += $file
        } elseif ($files1[$file].Hash -ne $files2[$file].Hash) {
            $diff.Different += $file
        }
    }

    return $diff
}

# 显示目录差异
function Show-DirectoryDiff {
    param(
        [hashtable]$Diff,
        [string]$DirName
    )

    Write-Host "[差异] $DirName — 目录内容不同：" -ForegroundColor Yellow

    foreach ($file in $Diff.OnlyInLocal) {
        Write-Host "  + $file (仅在本地存在)" -ForegroundColor Green
    }

    foreach ($file in $Diff.OnlyInSource) {
        Write-Host "  - $file (仅在源目录存在)" -ForegroundColor Red
    }

    foreach ($file in $Diff.Different) {
        Write-Host "  ~ $file (内容不同)" -ForegroundColor Cyan
    }

    if ($Diff.Ignored.Count -gt 0) {
        foreach ($file in $Diff.Ignored) {
            Write-Host "  ○ $file (本地配置，已忽略)" -ForegroundColor DarkGray
        }
    }
}

# 备份本地配置文件
function Backup-LocalConfigs {
    param(
        [string]$TargetPath,
        [string]$DirName
    )

    $backups = @{}
    foreach ($pattern in $script:LocalConfigFiles) {
        if ($pattern.StartsWith("$DirName/")) {
            $relativePath = $pattern.Substring($DirName.Length + 1)
            $fullPath = Join-Path $TargetPath $relativePath
            if (Test-Path $fullPath) {
                $backups[$relativePath] = Get-Content -Path $fullPath -Raw
            }
        }
    }
    return $backups
}

# 恢复本地配置文件
function Restore-LocalConfigs {
    param(
        [string]$TargetPath,
        [hashtable]$Backups
    )

    foreach ($file in $Backups.Keys) {
        $fullPath = Join-Path $TargetPath $file
        $dir = Split-Path -Parent $fullPath
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        Set-Content -Path $fullPath -Value $Backups[$file] -NoNewline
    }
}

# 特殊处理：某些目录只链接子目录而不是整个目录
# 定义需要链接的子目录
$SubdirLinks = @{
    ".claude" = @("skills", "commands")
    ".cursor" = @("skills", "commands")
    ".opencode" = @("skills", "command")
    ".trae" = @("skills")
    ".windsurf" = @("skills", "workflows")
    ".github" = @("agents", "prompts", "skills")
    ".specify" = @("scripts", "templates")
}

# 处理子目录链接的通用函数
function Handle-SubdirLinks {
    param(
        [string]$DirName,
        [string[]]$Subdirs
    )

    $sourceDir = Join-Path $ScriptDir $DirName
    $targetDir = Join-Path (Get-Location) $DirName

    # 如果源目录不存在，跳过
    if (-not (Test-Path $sourceDir)) {
        Write-Host "[跳过] $DirName — 源目录不存在" -ForegroundColor Yellow
        return @()
    }

    # 如果目标是一个符号链接，先删除它
    if (Test-Path $targetDir) {
        $item = Get-Item $targetDir -Force
        if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            Write-Host "[检测] $DirName 是符号链接，将替换为目录结构" -ForegroundColor Cyan
            Remove-Item -Path $targetDir -Force
        }
    }

    # 确保目标目录存在
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }

    $gitignoreEntries = @()

    # 处理每个子目录
    foreach ($subdir in $Subdirs) {
        $sourceSubdir = Join-Path $sourceDir $subdir
        $targetSubdir = Join-Path $targetDir $subdir

        # 检查源子目录是否存在
        if (-not (Test-Path $sourceSubdir)) {
            Write-Host "[跳过] $DirName/$subdir — 源目录不存在" -ForegroundColor Yellow
            continue
        }

        # 如果目标已经是符号链接
        if (Test-Path $targetSubdir) {
            $item = Get-Item $targetSubdir -Force
            if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
                Write-Host "[已有] $DirName/$subdir — 符号链接已存在" -ForegroundColor DarkGray
            } else {
                # 目标存在但不是符号链接
                if ($script:Force) {
                    Write-Host "[强制] $DirName/$subdir — 替换为符号链接" -ForegroundColor Yellow
                    Remove-Item -Path $targetSubdir -Recurse -Force
                    New-Item -ItemType SymbolicLink -Path $targetSubdir -Target $sourceSubdir | Out-Null
                    Write-Host "[完成] $DirName/$subdir -> $sourceSubdir" -ForegroundColor Green
                } else {
                    Write-Host "[跳过] $DirName/$subdir — 目录已存在（使用 -Force 强制替换）" -ForegroundColor Yellow
                }
            }
        } else {
            # 目标不存在，创建符号链接
            New-Item -ItemType SymbolicLink -Path $targetSubdir -Target $sourceSubdir | Out-Null
            Write-Host "[完成] $DirName/$subdir -> $sourceSubdir" -ForegroundColor Green
        }

        # 记录需要加入 .gitignore 的条目
        $gitignoreEntries += "$DirName/$subdir/"
    }

    return $gitignoreEntries
}

Write-Host ""
Write-Host "=== ai-settings 安装脚本 ===" -ForegroundColor Cyan
Write-Host "源目录: $ScriptDir"
Write-Host "目标目录: $(Get-Location)"
Write-Host ""

# 权限检查
if (-not (Test-SymlinkPermission)) {
    Write-Host "[错误] 没有创建符号链接的权限。请以管理员身份运行 PowerShell，或开启开发者模式：" -ForegroundColor Red
    Write-Host "       设置 -> 系统 -> 高级 -> 开发者模式" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

$GitignoreEntries = @()

foreach ($dir in $TargetDirs) {
    $dir = $dir.Trim()

    # 特殊处理：某些目录只链接子目录
    if ($SubdirLinks.ContainsKey($dir)) {
        $entries = Handle-SubdirLinks -DirName $dir -Subdirs $SubdirLinks[$dir]
        $GitignoreEntries += $entries
        continue
    }

    $sourcePath = Join-Path $ScriptDir $dir
    $targetPath = Join-Path (Get-Location) $dir

    # 检查源目录是否存在
    if (-not (Test-Path $sourcePath)) {
        Write-Host "[跳过] $dir — 源目录不存在: $sourcePath" -ForegroundColor Yellow
        continue
    }

    # 检查目标是否已存在
    if (Test-Path $targetPath) {
        $item = Get-Item $targetPath -Force
        if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            Write-Host "[已有] $dir — 符号链接已存在" -ForegroundColor DarkGray
        } else {
            # 目录存在但不是符号链接，比较内容
            if (Compare-Directories -Path1 $sourcePath -Path2 $targetPath) {
                # 内容相同，询问用户是否替换
                if ($Force) {
                    $replace = $true
                } else {
                    Write-Host "[相同] $dir — 内容与源目录相同" -ForegroundColor Cyan
                    $response = Read-Host "是否替换为符号链接？(y/N)"
                    $replace = $response -eq "y" -or $response -eq "Y"
                }

                if ($replace) {
                    $localConfigs = Backup-LocalConfigs -TargetPath $targetPath -DirName $dir
                    Remove-Item -Path $targetPath -Recurse -Force
                    New-Item -ItemType SymbolicLink -Path $targetPath -Target $sourcePath | Out-Null
                    Restore-LocalConfigs -TargetPath $targetPath -Backups $localConfigs
                    Write-Host "[完成] $dir -> $sourcePath （已替换为符号链接）" -ForegroundColor Green
                } else {
                    Write-Host "[跳过] $dir — 用户选择不替换" -ForegroundColor Yellow
                }
            } else {
                # 内容不同，获取详细差异
                $diff = Get-DirectoryDiff -Path1 $sourcePath -Path2 $targetPath -DirName $dir

                # 如果只有"仅在源目录存在"的文件或只有被忽略的文件，说明是安全的，可以直接替换
                $isSafeToReplace = ($diff.OnlyInLocal.Count -eq 0) -and ($diff.Different.Count -eq 0) -and
                                   (($diff.OnlyInSource.Count -gt 0) -or ($diff.Ignored.Count -gt 0))

                if ($isSafeToReplace) {
                    Write-Host "[安全] $dir — 目标目录缺少部分源文件，可以安全替换" -ForegroundColor Cyan
                    Show-DirectoryDiff -Diff $diff -DirName $dir
                    $localConfigs = Backup-LocalConfigs -TargetPath $targetPath -DirName $dir
                    Remove-Item -Path $targetPath -Recurse -Force
                    New-Item -ItemType SymbolicLink -Path $targetPath -Target $sourcePath | Out-Null
                    Restore-LocalConfigs -TargetPath $targetPath -Backups $localConfigs
                    Write-Host "[完成] $dir -> $sourcePath （已替换为符号链接）" -ForegroundColor Green
                } else {
                    # 有冲突，需要用户决定
                    Show-DirectoryDiff -Diff $diff -DirName $dir
                    if ($Force) {
                        Write-Host "[强制] 使用 -Force 参数，替换为符号链接" -ForegroundColor Yellow
                        $localConfigs = Backup-LocalConfigs -TargetPath $targetPath -DirName $dir
                        Remove-Item -Path $targetPath -Recurse -Force
                        New-Item -ItemType SymbolicLink -Path $targetPath -Target $sourcePath | Out-Null
                        Restore-LocalConfigs -TargetPath $targetPath -Backups $localConfigs
                        Write-Host "[完成] $dir -> $sourcePath （已强制替换）" -ForegroundColor Green
                    } else {
                        Write-Host "[跳过] $dir — 使用 -Force 参数可强制替换为符号链接" -ForegroundColor Yellow
                    }
                }
            }
        }
    } else {
        New-Item -ItemType SymbolicLink -Path $targetPath -Target $sourcePath | Out-Null
        Write-Host "[完成] $dir -> $sourcePath" -ForegroundColor Green
    }

    $GitignoreEntries += "$dir/"
}

# 更新 .gitignore
Write-Host ""
$gitignorePath = Join-Path (Get-Location) ".gitignore"

# 合并所有需要添加到 .gitignore 的条目
$allGitignoreEntries = $GitignoreEntries + @(
    "",
    "# 本地配置文件（不要提交）",
    ".claude/settings.local.json",
    ".cursor/settings.local.json",
    ".windsurf/settings.local.json"
)

if (Test-Path $gitignorePath) {
    $lines = Get-Content $gitignorePath

    # 特殊处理：移除旧的整个目录条目，将被子目录条目替换
    $removed = 0
    foreach ($dir in $SubdirLinks.Keys) {
        $pattern = "^" + [regex]::Escape($dir) + "/\s*$"
        # 过滤掉匹配的行（处理不同的行尾符）
        $newLines = $lines | Where-Object { $_ -notmatch $pattern }
        if ($newLines.Count -lt $lines.Count) {
            $lines = $newLines
            Set-Content -Path $gitignorePath -Value $lines
            Write-Host "[.gitignore] 已移除旧的 $dir/ 条目" -ForegroundColor Cyan
            $removed++
        }
    }

    # 重新读取文件（如果有修改）
    if ($removed -gt 0) {
        $lines = Get-Content $gitignorePath
    }

    $added = 0
    foreach ($entry in $allGitignoreEntries) {
        # 跳过空行和注释（它们可能重复）
        if ($entry -eq "" -or $entry.StartsWith("#")) {
            continue
        }
        # 检查是否已存在该条目（精确行匹配）
        if ($entry -notin $lines) {
            Add-Content -Path $gitignorePath -Value $entry
            $added++
        }
    }
    if ($added -gt 0) {
        Write-Host "[.gitignore] 已添加 $added 条记录" -ForegroundColor Green
    } else {
        Write-Host "[.gitignore] 无需更新（所有条目已存在）" -ForegroundColor DarkGray
    }
} else {
    $lines = @("# AI settings（符号链接自 ai-settings 仓库）")
    $lines += $allGitignoreEntries
    $lines | Set-Content -Path $gitignorePath
    Write-Host "[.gitignore] 已创建并添加 $($allGitignoreEntries.Count) 条记录" -ForegroundColor Green
}

Write-Host ""
Write-Host "安装完成！" -ForegroundColor Cyan
Write-Host ""
