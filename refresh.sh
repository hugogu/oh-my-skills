#!/usr/bin/env bash
#
# ai-settings 内容刷新脚本 (macOS / Linux / WSL)
#
# 用法:
#   ~/ai-settings/refresh.sh                     # 交互模式，刷新所有工具
#   ~/ai-settings/refresh.sh --auto              # 自动模式（需要 expect）
#   ~/ai-settings/refresh.sh --tools openspec    # 只运行 openspec init
#   ~/ai-settings/refresh.sh --manual            # 手动模式，显示每个命令
#

set -euo pipefail

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 支持的工具列表
TOOLS_TO_REFRESH=("openspec" "specify")

# 目标 AI 工具/环境列表（按顺序）
# 这些对应 openspec init 和 specify init 的选项
TARGET_TOOLS_ORDERED=(
    "Claude Code"
    "Cursor"
    "OpenCode"
    "Trae"
    "Windsurf"
    "GitHub Copilot"
    "Specify"
)

# 工具名称到选项编号的映射（根据实际命令调整）
declare -A TOOL_TO_NUMBER=(
    ["Claude Code"]="1"
    ["Cursor"]="2"
    ["OpenCode"]="3"
    ["Trae"]="4"
    ["Windsurf"]="5"
    ["GitHub Copilot"]="6"
    ["Specify"]="7"
)

# 映射显示名称到 specify --ai 参数
declare -A TOOL_TO_SPECIFY_AI=(
    ["Claude Code"]="claude"
    ["Cursor"]="cursor-agent"
    ["OpenCode"]="opencode"
    ["Windsurf"]="windsurf"
    ["GitHub Copilot"]="copilot"
)

# 解析参数
TOOLS_FILTER=""
AUTO_COMMIT=false
VERBOSE=false
MODE="interactive"  # interactive, manual

while [[ $# -gt 0 ]]; do
    case $1 in
        --tools)
            TOOLS_FILTER="$2"
            shift 2
            ;;
        --commit)
            AUTO_COMMIT=true
            shift
            ;;
        --manual)
            MODE="manual"
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            echo "用法: $0 [选项]"
            echo ""
            echo "选项:"
            echo "  --tools <name>    只运行指定工具 (openspec 或 specify)"
            echo "  --commit          自动提交更改到 git"
            echo "  --manual          手动模式（显示需要运行的命令）"
            echo "  --verbose, -v     显示详细输出"
            echo "  --help, -h        显示此帮助信息"
            echo ""
            echo "模式说明:"
            echo "  interactive (默认)  交互模式，运行命令并手动选择工具"
            echo "  manual              仅显示需要运行的命令和选择的工具"
            echo ""
            echo "注意:"
            echo "  openspec init 和 specify init 允许一次选择多个工具"
            echo "  脚本会运行命令一次，你需要选择所有需要的工具"
            echo ""
            echo "示例:"
            echo "  $0                         # 交互模式"
            echo "  $0 --manual                # 显示命令列表"
            echo "  $0 --tools openspec        # 只运行 openspec init"
            echo "  $0 --commit                # 交互模式并提交"
            exit 0
            ;;
        *)
            echo "错误: 未知参数 '$1'"
            echo "使用 --help 查看帮助"
            exit 1
            ;;
    esac
done

# 检查命令是否存在
check_command() {
    local cmd="$1"
    if ! command -v "$cmd" &> /dev/null; then
        echo "[错误] 命令 '$cmd' 未找到，请先安装"
        return 1
    fi
    return 0
}

# 主逻辑
main() {
    echo ""
    echo "=== ai-settings 内容刷新脚本 ==="
    echo "仓库目录: $SCRIPT_DIR"
    echo ""

    # 切换到仓库目录
    cd "$SCRIPT_DIR"

    # 检查是否是 git 仓库
    if [ ! -d ".git" ]; then
        echo "[错误] 当前目录不是 git 仓库"
        exit 1
    fi

    # 检查工作目录是否干净
    if ! git diff --quiet || ! git diff --cached --quiet; then
        echo "[警告] 工作目录有未提交的更改"
        read -p "是否继续？(y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "已取消"
            exit 0
        fi
    fi

    # 确定要运行的工具
    local tools_to_run=()
    if [ -n "$TOOLS_FILTER" ]; then
        tools_to_run=("$TOOLS_FILTER")
    else
        tools_to_run=("${TOOLS_TO_REFRESH[@]}")
    fi

    # 对每个工具运行初始化
    for tool in "${tools_to_run[@]}"; do
        echo ""
        echo "────────────────────────────────────────"
        echo "运行工具: $tool init"
        echo "────────────────────────────────────────"

        # 检查命令是否存在
        if ! check_command "$tool"; then
            echo "[跳过] $tool 命令不可用"
            continue
        fi

        # 处理 specify 工具（需要为每个 AI 工具运行一次）
        if [ "$tool" = "specify" ]; then
            echo "自动运行 specify init，为每个 AI 工具生成配置..."
            echo ""

            local specify_failed=false
            for tool_name in "${TARGET_TOOLS_ORDERED[@]}"; do
                # Use default empty value if key doesn't exist (for set -u compatibility)
                local ai_param="${TOOL_TO_SPECIFY_AI[$tool_name]:-}"

                # 跳过没有映射的工具
                if [ -z "$ai_param" ]; then
                    continue
                fi

                echo "  → 配置 $tool_name (--ai $ai_param)"

                if ! specify init --here --force --ai "$ai_param" --script sh > /dev/null 2>&1; then
                    echo "     [警告] 配置 $tool_name 失败"
                    specify_failed=true
                else
                    echo "     [完成] 配置 $tool_name 成功"
                fi
            done

            if [ "$specify_failed" = true ]; then
                echo ""
                echo "[警告] 部分配置失败，但继续执行"
            fi
        else
            # 其他工具（如 openspec）使用原来的交互模式
            local cmd="${tool} init"

            # 显示要选择的工具列表
            echo "需要选择的工具："
            for tool_name in "${TARGET_TOOLS_ORDERED[@]}"; do
                echo "  ✓ $tool_name"
            done
            echo ""

            # 根据模式运行命令
            if [ "$MODE" = "manual" ]; then
                echo "[手动模式] 请运行以下命令："
                echo "  $cmd"
                echo ""
                echo "在提示时选择以下工具："
                for tool_name in "${TARGET_TOOLS_ORDERED[@]}"; do
                    echo "  - $tool_name"
                done
            else
                # 交互模式 - 直接运行
                echo "[交互模式] 请在提示时选择所有需要的工具"
                echo ""
                $cmd || {
                    echo "[警告] 执行失败或用户取消"
                }
            fi
        fi

        echo ""
        echo "[完成] $tool init"
    done

    echo ""
    echo "────────────────────────────────────────"
    echo "刷新完成！"
    echo "────────────────────────────────────────"
    echo ""

    # 显示更改的文件
    if git diff --quiet && git diff --cached --quiet; then
        echo "[信息] 没有文件被修改"
    else
        echo "已修改的文件:"
        git status --short
        echo ""

        # 自动提交或询问
        if [ "$AUTO_COMMIT" = true ]; then
            echo "[自动提交] 提交更改到 git..."
            git add -A
            git commit -m "chore: Refresh AI tool configurations

Updated configurations for all AI tools using:
$(for t in "${tools_to_run[@]}"; do echo "- $t init"; done)

Auto-generated by refresh.sh" || echo "[警告] 提交失败"
        else
            read -p "是否提交更改到 git？(y/N) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                git add -A
                git commit -m "chore: Refresh AI tool configurations

Updated configurations for all AI tools using:
$(for t in "${tools_to_run[@]}"; do echo "- $t init"; done)

Generated by refresh.sh"
                echo "[完成] 更改已提交"
            else
                echo "[跳过] 未提交更改"
            fi
        fi
    fi

    echo ""
    echo "完成！"
}

main
