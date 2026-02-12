#!/usr/bin/env bash
#
# ai-settings 快速安装脚本 (macOS / Linux / WSL)
#
# 用法:
#   ~/ai-settings/setup.sh                    # 链接所有目录
#   ~/ai-settings/setup.sh .claude .cursor    # 只链接指定目录
#   ~/ai-settings/setup.sh --force            # 强制替换所有目录为符号链接
#
# 注意: 在 WSL 上，为了让 Windows 也能识别符号链接，建议：
#   1. 使用 PowerShell 脚本: setup.ps1 -Force
#   2. 或在 /etc/wsl.conf 中启用 metadata 选项
#

set -euo pipefail

# 检查 Bash 版本（需要 4.0+ 以支持关联数组）
if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
    # 尝试查找并使用更新的 bash 版本
    for bash_path in /usr/local/bin/bash /opt/homebrew/bin/bash; do
        if [ -x "$bash_path" ]; then
            bash_version=$("$bash_path" -c 'echo ${BASH_VERSINFO[0]}')
            if [ "$bash_version" -ge 4 ]; then
                echo "检测到旧版 Bash ($BASH_VERSION)，自动切换到 $bash_path"
                exec "$bash_path" "$0" "$@"
            fi
        fi
    done

    # 如果没有找到合适的 bash，显示错误信息
    echo "错误: 此脚本需要 Bash 4.0 或更高版本（当前版本: $BASH_VERSION）"
    echo ""
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "在 macOS 上，请安装 Homebrew bash："
        echo "  brew install bash"
    else
        echo "请升级您的 bash 版本"
    fi
    exit 1
fi

# 检测是否在 WSL 环境中
IS_WSL=false
if grep -qEi "(Microsoft|WSL)" /proc/version &> /dev/null; then
    IS_WSL=true
fi

# 检查符号链接是否是 Windows 兼容的（通过 mklink 创建）
is_windows_symlink() {
    local link="$1"

    if [ ! -L "$link" ]; then
        return 1  # 不是符号链接
    fi

    if [ "$IS_WSL" = false ]; then
        return 0  # 不在 WSL 中，假设是兼容的
    fi

    # 在 WSL 中，检查符号链接类型
    # Windows 符号链接有特殊的文件系统属性
    # 使用 PowerShell 检查目标是否为空（WSL 符号链接在 Windows 中显示为空目标）
    local win_link=$(wslpath -w "$link" 2>/dev/null)
    if [ -z "$win_link" ]; then
        return 1  # 无法转换为 Windows 路径
    fi

    # 使用 PowerShell 检查符号链接的目标
    # Windows 符号链接会有正确的目标，WSL 符号链接目标为空
    set +e
    local target=$(powershell.exe -NoProfile -Command "(Get-Item '$win_link' -Force -ErrorAction SilentlyContinue).Target" 2>/dev/null | tr -d '\r\n')
    set -e

    # 如果目标为空或获取失败，说明是 WSL 符号链接
    if [ -z "$target" ]; then
        return 1  # WSL 符号链接
    else
        return 0  # Windows 符号链接
    fi
}

# 创建符号链接（WSL 兼容）
# 参数：target link [force_recreate]
create_symlink() {
    local target="$1"
    local link="$2"
    local force_recreate="${3:-false}"

    if [ "$IS_WSL" = true ]; then
        # 在 WSL 中，转换路径并使用 Windows 的 mklink 创建符号链接
        # 这样创建的符号链接在 Windows 和 WSL 中都可用
        local win_target=$(wslpath -w "$target")
        local win_link=$(wslpath -w "$link")

        # 使用 cmd.exe 调用 mklink /D 创建目录符号链接
        # 临时禁用错误退出，以便我们可以处理失败情况
        set +e
        cmd.exe /c "mklink /D $win_link $win_target" > /dev/null 2>&1
        local result=$?
        set -e

        if [ $result -eq 0 ]; then
            return 0
        else
            # 如果失败，回退到普通的 ln -s
            echo "  [警告] Windows mklink 失败，使用 WSL symlink（Windows 可能无法识别）" >&2
            ln -s "$target" "$link"
            return 0
        fi
    else
        # 在非 WSL 环境中，使用标准的 ln -s
        ln -s "$target" "$link"
        return 0
    fi
}

# 解析参数
FORCE=false
DIRS_ARGS=()

for arg in "$@"; do
    if [ "$arg" = "--force" ] || [ "$arg" = "-f" ]; then
        FORCE=true
    else
        DIRS_ARGS+=("$arg")
    fi
done

# 获取脚本自身所在目录（即 ai-settings 仓库根目录）
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 可链接的所有目录
# 注意：某些目录会特殊处理，只链接部分子目录：
#   - .claude: 只链接 skills, commands (保留本地的 settings.local.json 等文件)
#   - .cursor: 只链接 skills, commands (保留本地的配置文件)
#   - .opencode: 只链接 skills, command (保留本地的配置文件)
#   - .trae: 只链接 skills (保留本地的配置文件)
#   - .windsurf: 只链接 skills, workflows (保留本地的 rules 目录)
#   - .github: 只链接 agents, prompts, skills (保留本地的 workflows, issue templates 等)
#   - .specify: 只链接 scripts, templates (保留本地的 memory, agent-context 目录)
ALL_DIRS=(.claude .cursor .windsurf .trae .opencode .github .specify)

# 本地配置文件列表（这些文件在差异比较时会被忽略，且在符号链接创建后会被保留）
# 注意：对于子目录链接的目录，配置文件位于父目录本身，不在符号链接中
LOCAL_CONFIG_FILES=(
    ".claude/settings.local.json"
    ".cursor/settings.local.json"
    ".windsurf/settings.local.json"
)

# 如果传入了目录参数，只链接指定的目录；否则链接全部
if [ ${#DIRS_ARGS[@]} -gt 0 ]; then
    DIRS=("${DIRS_ARGS[@]}")
else
    DIRS=("${ALL_DIRS[@]}")
fi

# 检查文件是否应该被忽略（本地配置文件）
should_ignore_file() {
    local file="$1"
    local dir_name="$2"

    for pattern in "${LOCAL_CONFIG_FILES[@]}"; do
        local full_path="$dir_name/$file"
        if [[ "$full_path" == "$pattern" ]]; then
            return 0  # 应该忽略
        fi
    done
    return 1  # 不忽略
}

# 备份本地配置文件
backup_local_configs() {
    local target_path="$1"
    local dir_name="$2"
    local backup_dir=$(mktemp -d)

    for pattern in "${LOCAL_CONFIG_FILES[@]}"; do
        if [[ "$pattern" == "$dir_name/"* ]]; then
            local relative_path="${pattern#$dir_name/}"
            local full_path="$target_path/$relative_path"
            if [ -f "$full_path" ]; then
                local backup_file="$backup_dir/$relative_path"
                mkdir -p "$(dirname "$backup_file")"
                cp "$full_path" "$backup_file"
            fi
        fi
    done
    echo "$backup_dir"
}

# 恢复本地配置文件
restore_local_configs() {
    local target_path="$1"
    local backup_dir="$2"

    if [ -d "$backup_dir" ]; then
        cd "$backup_dir" && find . -type f | while read -r file; do
            local target_file="$target_path/$file"
            mkdir -p "$(dirname "$target_file")"
            cp "$backup_dir/$file" "$target_file"
        done
        rm -rf "$backup_dir"
    fi
}

# 比较两个目录是否内容相同
compare_directories() {
    local dir1="$1"
    local dir2="$2"

    # 使用 find 和 md5sum/md5 比较所有文件
    if command -v md5sum &> /dev/null; then
        local hash_cmd="md5sum"
    elif command -v md5 &> /dev/null; then
        local hash_cmd="md5 -r"
    else
        echo "错误: 需要 md5sum 或 md5 命令"
        return 2
    fi

    local hash1=$(cd "$dir1" && find . -type f -exec $hash_cmd {} \; | sort -k 2 | $hash_cmd | cut -d' ' -f1)
    local hash2=$(cd "$dir2" && find . -type f -exec $hash_cmd {} \; | sort -k 2 | $hash_cmd | cut -d' ' -f1)

    [ "$hash1" = "$hash2" ]
}

# 检查是否只有"仅在源目录存在"的差异（即安全替换）
is_safe_to_replace() {
    local dir1="$1"
    local dir2="$2"
    local dir_name="$3"

    # 检查是否有仅在本地存在的文件（排除本地配置文件）
    local only_in_local_count=0
    while IFS= read -r file; do
        [ -z "$file" ] && continue
        if ! should_ignore_file "$file" "$dir_name"; then
            only_in_local_count=$((only_in_local_count + 1))
        fi
    done < <(cd "$dir2" && find . -type f | while read f; do [ ! -f "$dir1/$f" ] && echo "$f"; done)

    if [ "$only_in_local_count" -gt 0 ]; then
        return 1  # 不安全
    fi

    # 检查是否有内容不同的文件（排除本地配置文件）
    if command -v md5sum &> /dev/null; then
        local hash_cmd="md5sum"
    else
        local hash_cmd="md5 -r"
    fi

    local different_count=0
    while IFS= read -r file; do
        [ -z "$file" ] && continue
        if should_ignore_file "$file" "$dir_name"; then
            continue
        fi
        if [ -f "$dir2/$file" ]; then
            local hash1=$(cd "$dir1" && $hash_cmd "$file" 2>/dev/null | cut -d' ' -f1)
            local hash2=$(cd "$dir2" && $hash_cmd "$file" 2>/dev/null | cut -d' ' -f1)
            if [ "$hash1" != "$hash2" ]; then
                different_count=$((different_count + 1))
            fi
        fi
    done < <(cd "$dir1" && find . -type f)

    if [ "$different_count" -gt 0 ]; then
        return 1  # 不安全
    fi

    # 检查是否有仅在源目录存在的文件
    local only_in_source=$(cd "$dir1" && find . -type f | while read f; do [ ! -f "$dir2/$f" ] && echo "$f"; done | wc -l)
    if [ "$only_in_source" -gt 0 ]; then
        return 0  # 安全
    fi

    # 检查是否有被忽略的文件（如果只有被忽略的文件，也是安全的）
    local ignored_count=0
    while IFS= read -r file; do
        [ -z "$file" ] && continue
        if should_ignore_file "$file" "$dir_name"; then
            ignored_count=$((ignored_count + 1))
        fi
    done < <(cd "$dir2" && find . -type f | while read f; do [ ! -f "$dir1/$f" ] && echo "$f"; done)

    if [ "$ignored_count" -gt 0 ]; then
        return 0  # 安全
    fi

    return 1  # 没有差异（但这不应该发生，因为调用前已经检查过内容相同）
}

# 显示目录差异
show_directory_diff() {
    local dir1="$1"
    local dir2="$2"
    local dir_name="$3"

    echo "[差异] $dir_name — 目录内容不同："

    # 列出仅在源目录存在的文件
    while IFS= read -r file; do
        [ -z "$file" ] && continue
        echo "  - $file (仅在源目录存在)"
    done < <(cd "$dir1" && find . -type f | while read f; do [ ! -f "$dir2/$f" ] && echo "$f"; done)

    # 列出仅在本地存在的文件（标记被忽略的文件）
    while IFS= read -r file; do
        [ -z "$file" ] && continue
        if should_ignore_file "$file" "$dir_name"; then
            echo "  ○ $file (本地配置，已忽略)"
        else
            echo "  + $file (仅在本地存在)"
        fi
    done < <(cd "$dir2" && find . -type f | while read f; do [ ! -f "$dir1/$f" ] && echo "$f"; done)

    # 列出内容不同的文件（标记被忽略的文件）
    if command -v md5sum &> /dev/null; then
        local hash_cmd="md5sum"
    else
        local hash_cmd="md5 -r"
    fi

    while IFS= read -r file; do
        [ -z "$file" ] && continue
        if [ -f "$dir2/$file" ]; then
            local hash1=$(cd "$dir1" && $hash_cmd "$file" 2>/dev/null | cut -d' ' -f1)
            local hash2=$(cd "$dir2" && $hash_cmd "$file" 2>/dev/null | cut -d' ' -f1)
            if [ "$hash1" != "$hash2" ]; then
                if should_ignore_file "$file" "$dir_name"; then
                    echo "  ○ $file (本地配置，已忽略)"
                else
                    echo "  ~ $file (内容不同)"
                fi
            fi
        fi
    done < <(cd "$dir1" && find . -type f)
}

# 需要添加到 .gitignore 的条目
GITIGNORE_ENTRIES=()

# 特殊处理：某些目录只链接子目录而不是整个目录
# 定义需要链接的子目录
declare -A SUBDIR_LINKS=(
    [".claude"]="skills commands"
    [".cursor"]="skills commands"
    [".opencode"]="skills command"
    [".trae"]="skills"
    [".windsurf"]="skills workflows"
    [".github"]="agents prompts skills"
    [".specify"]="scripts templates"
)

# 处理子目录链接的通用函数
handle_subdir_links() {
    local dir_name="$1"
    local subdirs="$2"
    local source_dir="$SCRIPT_DIR/$dir_name"
    local target_dir="./$dir_name"

    # 如果源目录不存在，跳过
    if [ ! -d "$source_dir" ]; then
        echo "[跳过] $dir_name — 源目录不存在"
        return
    fi

    # 如果目标是一个符号链接，先删除它
    if [ -L "$target_dir" ]; then
        echo "[检测] $dir_name 是符号链接，将替换为目录结构"
        rm -f "$target_dir"
    fi

    # 确保目标目录存在
    mkdir -p "$target_dir"

    # 处理每个子目录
    for subdir in $subdirs; do
        local source_subdir="$source_dir/$subdir"
        local target_subdir="$target_dir/$subdir"

        # 检查源子目录是否存在
        if [ ! -d "$source_subdir" ]; then
            echo "[跳过] $dir_name/$subdir — 源目录不存在"
            continue
        fi

        # 如果目标已经是符号链接
        if [ -L "$target_subdir" ]; then
            # 检查是否需要修复 WSL 符号链接
            if [ "$IS_WSL" = true ] && ! is_windows_symlink "$target_subdir"; then
                echo "[修复] $dir_name/$subdir — 转换为 Windows 兼容符号链接"
                rm -f "$target_subdir"
                create_symlink "$source_subdir" "$target_subdir"
                echo "[完成] $dir_name/$subdir -> $source_subdir （已修复）"
            else
                echo "[已有] $dir_name/$subdir — 符号链接已存在"
            fi
        # 如果目标存在但不是符号链接
        elif [ -e "$target_subdir" ]; then
            if [ "$FORCE" = true ]; then
                echo "[强制] $dir_name/$subdir — 替换为符号链接"
                rm -rf "$target_subdir"
                create_symlink "$source_subdir" "$target_subdir"
                echo "[完成] $dir_name/$subdir -> $source_subdir"
            else
                echo "[跳过] $dir_name/$subdir — 目录已存在（使用 --force 强制替换）"
            fi
        # 目标不存在，创建符号链接
        else
            create_symlink "$source_subdir" "$target_subdir"
            echo "[完成] $dir_name/$subdir -> $source_subdir"
        fi

        # 记录需要加入 .gitignore 的条目
        GITIGNORE_ENTRIES+=("$dir_name/$subdir/")
    done
}

echo ""
echo "=== ai-settings 安装脚本 ==="
echo "源目录: $SCRIPT_DIR"
echo "目标目录: $(pwd)"
echo ""

for dir in "${DIRS[@]}"; do
    # 特殊处理：某些目录只链接子目录
    if [[ -n "${SUBDIR_LINKS[$dir]:-}" ]]; then
        handle_subdir_links "$dir" "${SUBDIR_LINKS[$dir]}"
        continue
    fi
    source_path="$SCRIPT_DIR/$dir"
    target_path="./$dir"

    # 检查源目录是否存在
    if [ ! -d "$source_path" ]; then
        echo "[跳过] $dir — 源目录不存在: $source_path"
        continue
    fi

    # 检查目标是否已存在
    if [ -e "$target_path" ] || [ -L "$target_path" ]; then
        if [ -L "$target_path" ]; then
            # 检查是否需要修复 WSL 符号链接
            if [ "$IS_WSL" = true ] && ! is_windows_symlink "$target_path"; then
                echo "[修复] $dir — 转换为 Windows 兼容符号链接"
                rm -f "$target_path"
                create_symlink "$source_path" "$target_path"
                echo "[完成] $dir -> $source_path （已修复）"
            else
                echo "[已有] $dir — 符号链接已存在"
            fi
        else
            # 目录存在但不是符号链接，比较内容
            if compare_directories "$source_path" "$target_path"; then
                # 内容相同，询问用户是否替换
                if [ "$FORCE" = true ]; then
                    replace=true
                else
                    echo "[相同] $dir — 内容与源目录相同"
                    read -p "是否替换为符号链接？(y/N) " -n 1 -r
                    echo
                    if [[ $REPLY =~ ^[Yy]$ ]]; then
                        replace=true
                    else
                        replace=false
                    fi
                fi

                if [ "$replace" = true ]; then
                    backup_dir=$(backup_local_configs "$target_path" "$dir")
                    rm -rf "$target_path"
                    create_symlink "$source_path" "$target_path"
                    restore_local_configs "$target_path" "$backup_dir"
                    echo "[完成] $dir -> $source_path （已替换为符号链接）"
                else
                    echo "[跳过] $dir — 用户选择不替换"
                fi
            else
                # 内容不同，检查是否安全替换
                if is_safe_to_replace "$source_path" "$target_path" "$dir"; then
                    echo "[安全] $dir — 目标目录缺少部分源文件，可以安全替换"
                    show_directory_diff "$source_path" "$target_path" "$dir"
                    backup_dir=$(backup_local_configs "$target_path" "$dir")
                    rm -rf "$target_path"
                    create_symlink "$source_path" "$target_path"
                    restore_local_configs "$target_path" "$backup_dir"
                    echo "[完成] $dir -> $source_path （已替换为符号链接）"
                else
                    # 有冲突，需要用户决定
                    show_directory_diff "$source_path" "$target_path" "$dir"
                    if [ "$FORCE" = true ]; then
                        echo "[强制] 使用 --force 参数，替换为符号链接"
                        backup_dir=$(backup_local_configs "$target_path" "$dir")
                        rm -rf "$target_path"
                        create_symlink "$source_path" "$target_path"
                        restore_local_configs "$target_path" "$backup_dir"
                        echo "[完成] $dir -> $source_path （已强制替换）"
                    else
                        echo "[跳过] $dir — 使用 --force 参数可强制替换为符号链接"
                    fi
                fi
            fi
        fi
    else
        create_symlink "$source_path" "$target_path"
        echo "[完成] $dir -> $source_path"
    fi

    # 记录需要加入 .gitignore 的条目
    GITIGNORE_ENTRIES+=("$dir/")
done

# 更新 .gitignore
echo ""
if [ -f .gitignore ]; then
    ADDED=0

    # 特殊处理：移除旧的整个目录条目，将被子目录条目替换
    for dir in "${!SUBDIR_LINKS[@]}"; do
        # 转义目录名中的特殊字符（如 .）
        escaped_dir=$(echo "$dir" | sed 's/\./\\./g')
        # 使用 sed 移除匹配的行（自动处理不同的行尾符）
        if grep -q "^${escaped_dir}/[[:space:]]*$" .gitignore; then
            sed -i.bak "/^${escaped_dir}\/[[:space:]]*$/d" .gitignore
            rm -f .gitignore.bak
            echo "[.gitignore] 已移除旧的 $dir/ 条目"
        fi
    done

    # 添加目录条目
    for entry in "${GITIGNORE_ENTRIES[@]}"; do
        if ! grep -qxF "$entry" .gitignore; then
            echo "$entry" >> .gitignore
            ADDED=$((ADDED + 1))
        fi
    done
    # 添加本地配置文件条目
    LOCAL_CONFIG_COMMENT="# 本地配置文件（不要提交）"
    if ! grep -qF "$LOCAL_CONFIG_COMMENT" .gitignore; then
        echo "" >> .gitignore
        echo "$LOCAL_CONFIG_COMMENT" >> .gitignore
    fi
    for entry in "${LOCAL_CONFIG_FILES[@]}"; do
        if ! grep -qxF "$entry" .gitignore; then
            echo "$entry" >> .gitignore
            ADDED=$((ADDED + 1))
        fi
    done
    if [ $ADDED -gt 0 ]; then
        echo "[.gitignore] 已添加 $ADDED 条记录"
    else
        echo "[.gitignore] 无需更新（所有条目已存在）"
    fi
else
    {
        echo "# AI settings（符号链接自 ai-settings 仓库）"
        for entry in "${GITIGNORE_ENTRIES[@]}"; do
            echo "$entry"
        done
        echo ""
        echo "# 本地配置文件（不要提交）"
        for entry in "${LOCAL_CONFIG_FILES[@]}"; do
            echo "$entry"
        done
    } > .gitignore
    TOTAL=$((${#GITIGNORE_ENTRIES[@]} + ${#LOCAL_CONFIG_FILES[@]}))
    echo "[.gitignore] 已创建并添加 $TOTAL 条记录"
fi

echo ""
echo "安装完成！"
echo ""
