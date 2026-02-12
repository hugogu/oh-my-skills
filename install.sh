#!/usr/bin/env bash
#
# OpenSpec & SpecKit 安装/升级脚本 (macOS / Linux / WSL)
#
# 用法:
#   ./install.sh                    # 检查并安装缺失的工具
#   ./install.sh --upgrade          # 升级已安装的工具到最新版本
#   ./install.sh --check            # 只检查安装状态，不安装
#   ./install.sh --force            # 强制重新安装
#

set -euo pipefail

# 配置
OPENSPEC_PACKAGE="@openspec/cli"
SPECKIT_REPO="https://github.com/github/spec-kit.git"

# 解析参数
MODE="install"  # install, upgrade, check, force
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --upgrade|-u)
            MODE="upgrade"
            shift
            ;;
        --check|-c)
            MODE="check"
            shift
            ;;
        --force|-f)
            MODE="force"
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
            echo "  --upgrade, -u     升级已安装的工具到最新版本"
            echo "  --check, -c       只检查安装状态，不安装"
            echo "  --force, -f       强制重新安装"
            echo "  --verbose, -v     显示详细输出"
            echo "  --help, -h        显示此帮助信息"
            echo ""
            echo "模式说明:"
            echo "  install (默认)    安装缺失的工具"
            echo "  upgrade           升级所有工具到最新版本"
            echo "  check             只检查不安装"
            echo "  force             强制重新安装所有工具"
            echo ""
            echo "示例:"
            echo "  $0                 # 安装缺失的工具"
            echo "  $0 --upgrade       # 升级所有工具"
            echo "  $0 --check         # 检查安装状态"
            exit 0
            ;;
        *)
            echo "错误: 未知参数 '$1'"
            echo "使用 --help 查看帮助"
            exit 1
            ;;
    esac
done

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# 检查命令是否存在
command_exists() {
    command -v "$1" &> /dev/null
}

# 获取包版本
get_package_version() {
    local cmd="$1"
    if command_exists "$cmd"; then
        $cmd --version 2>/dev/null | head -n 1 || echo "unknown"
    else
        echo "not installed"
    fi
}

# 获取 npm 包的最新版本
get_latest_version() {
    local package="$1"
    npm view "$package" version 2>/dev/null || echo "unknown"
}

# 检查 Node.js 和 npm
check_nodejs() {
    if ! command_exists node; then
        print_error "Node.js 未安装"
        echo ""
        echo "请先安装 Node.js:"
        echo "  Ubuntu/Debian: sudo apt-get install nodejs npm"
        echo "  macOS:         brew install node"
        echo "  或访问:        https://nodejs.org/"
        return 1
    fi

    if ! command_exists npm; then
        print_error "npm 未安装"
        echo ""
        echo "请安装 npm (通常随 Node.js 一起安装)"
        return 1
    fi

    local node_version=$(node --version)
    local npm_version=$(npm --version)
    print_success "Node.js $node_version"
    print_success "npm $npm_version"
    return 0
}

# 检查 uv
check_uv() {
    if ! command_exists uv; then
        return 1
    fi

    local uv_version=$(uv --version)
    print_success "uv $uv_version"
    return 0
}

# 安装 uv
install_uv() {
    print_info "安装 uv..."
    echo ""

    if [ "$VERBOSE" = true ]; then
        curl -LsSf https://astral.sh/uv/install.sh | sh
    else
        curl -LsSf https://astral.sh/uv/install.sh | sh > /dev/null 2>&1
    fi

    # 重新加载 shell 配置以获取 uv 路径
    if [ -f "$HOME/.cargo/env" ]; then
        source "$HOME/.cargo/env"
    fi

    # 验证安装
    if command_exists uv; then
        local uv_version=$(uv --version)
        print_success "uv 已安装 ($uv_version)"
        return 0
    else
        print_error "uv 安装失败"
        echo ""
        echo "请手动安装: curl -LsSf https://astral.sh/uv/install.sh | sh"
        echo "然后重新运行此脚本"
        return 1
    fi
}

# 安装或升级 npm 包
install_package() {
    local package="$1"
    local cmd="$2"
    local action="$3"  # install, upgrade, force

    echo ""
    echo "────────────────────────────────────────"
    echo "处理: $package (npm)"
    echo "────────────────────────────────────────"

    local current_version=$(get_package_version "$cmd")
    local latest_version=$(get_latest_version "$package")

    echo "当前版本: $current_version"
    echo "最新版本: $latest_version"
    echo ""

    case $action in
        install)
            if [ "$current_version" = "not installed" ]; then
                print_info "安装 $package..."
                if [ "$VERBOSE" = true ]; then
                    npm install -g "$package"
                else
                    npm install -g "$package" > /dev/null 2>&1
                fi
                print_success "已安装 $package"
            else
                print_success "$cmd 已安装 (v$current_version)"
            fi
            ;;
        upgrade)
            if [ "$current_version" = "not installed" ]; then
                print_warning "$cmd 未安装，将进行安装"
                if [ "$VERBOSE" = true ]; then
                    npm install -g "$package"
                else
                    npm install -g "$package" > /dev/null 2>&1
                fi
                print_success "已安装 $package"
            else
                print_info "升级 $package..."
                if [ "$VERBOSE" = true ]; then
                    npm install -g "$package@latest"
                else
                    npm install -g "$package@latest" > /dev/null 2>&1
                fi
                local new_version=$(get_package_version "$cmd")
                print_success "已升级到 v$new_version"
            fi
            ;;
        force)
            print_info "强制重新安装 $package..."
            if [ "$VERBOSE" = true ]; then
                npm uninstall -g "$package" 2>/dev/null || true
                npm install -g "$package"
            else
                npm uninstall -g "$package" > /dev/null 2>&1 || true
                npm install -g "$package" > /dev/null 2>&1
            fi
            local new_version=$(get_package_version "$cmd")
            print_success "已重新安装 v$new_version"
            ;;
    esac
}

# 安装或升级 uv 工具
install_uv_tool() {
    local tool_name="$1"  # specify-cli
    local repo="$2"       # git repo URL
    local cmd="$3"        # specify
    local action="$4"     # install, upgrade, force

    echo ""
    echo "────────────────────────────────────────"
    echo "处理: $tool_name (uv tool)"
    echo "────────────────────────────────────────"

    local current_version=$(get_package_version "$cmd")

    echo "当前版本: $current_version"
    echo ""

    case $action in
        install)
            if [ "$current_version" = "not installed" ]; then
                print_info "安装 $tool_name..."
                if [ "$VERBOSE" = true ]; then
                    uv tool install "$tool_name" --from "git+$repo"
                else
                    uv tool install "$tool_name" --from "git+$repo" > /dev/null 2>&1
                fi
                print_success "已安装 $tool_name"
            else
                print_success "$cmd 已安装 (v$current_version)"
            fi
            ;;
        upgrade)
            if [ "$current_version" = "not installed" ]; then
                print_warning "$cmd 未安装，将进行安装"
                if [ "$VERBOSE" = true ]; then
                    uv tool install "$tool_name" --from "git+$repo"
                else
                    uv tool install "$tool_name" --from "git+$repo" > /dev/null 2>&1
                fi
                print_success "已安装 $tool_name"
            else
                print_info "升级 $tool_name..."
                if [ "$VERBOSE" = true ]; then
                    uv tool upgrade "$tool_name"
                else
                    uv tool upgrade "$tool_name" > /dev/null 2>&1
                fi
                local new_version=$(get_package_version "$cmd")
                print_success "已升级到 v$new_version"
            fi
            ;;
        force)
            print_info "强制重新安装 $tool_name..."
            if [ "$VERBOSE" = true ]; then
                uv tool uninstall "$tool_name" 2>/dev/null || true
                uv tool install "$tool_name" --from "git+$repo"
            else
                uv tool uninstall "$tool_name" > /dev/null 2>&1 || true
                uv tool install "$tool_name" --from "git+$repo" > /dev/null 2>&1
            fi
            local new_version=$(get_package_version "$cmd")
            print_success "已重新安装 v$new_version"
            ;;
    esac
}

# 主函数
main() {
    echo ""
    echo "═══════════════════════════════════════════════════"
    echo "  OpenSpec & SpecKit 安装脚本"
    echo "═══════════════════════════════════════════════════"
    echo ""

    # 检查依赖
    print_info "检查依赖..."

    # 检查 Node.js 和 npm (用于 openspec)
    if ! check_nodejs; then
        exit 1
    fi

    echo ""

    # 检查 uv (用于 speckit)
    if ! check_uv; then
        print_warning "uv 未安装 (SpecKit 需要 uv)"
        echo ""

        if [ "$MODE" = "check" ]; then
            SKIP_SPECKIT=true
        else
            read -p "是否自动安装 uv？(Y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Nn]$ ]]; then
                print_info "跳过 uv 安装，将不安装 SpecKit"
                SKIP_SPECKIT=true
            else
                if install_uv; then
                    SKIP_SPECKIT=false
                else
                    SKIP_SPECKIT=true
                fi
            fi
        fi
    else
        SKIP_SPECKIT=false
    fi

    echo ""
    print_info "检查工具状态..."

    # 获取当前版本
    local openspec_version=$(get_package_version "openspec")
    local speckit_version=$(get_package_version "specify")

    echo "  openspec: $openspec_version"
    echo "  speckit:  $speckit_version"

    # 根据模式执行操作
    case $MODE in
        check)
            echo ""
            print_info "检查模式 - 不执行安装操作"
            if [ "$openspec_version" = "not installed" ]; then
                print_warning "openspec 未安装"
            else
                print_success "openspec 已安装 (v$openspec_version)"
            fi
            if [ "$speckit_version" = "not installed" ]; then
                print_warning "specify 未安装"
            else
                print_success "specify 已安装 (v$speckit_version)"
            fi
            ;;
        install)
            install_package "$OPENSPEC_PACKAGE" "openspec" "install"
            if [ "$SKIP_SPECKIT" = false ]; then
                install_uv_tool "specify-cli" "$SPECKIT_REPO" "specify" "install"
            fi
            ;;
        upgrade)
            install_package "$OPENSPEC_PACKAGE" "openspec" "upgrade"
            if [ "$SKIP_SPECKIT" = false ]; then
                install_uv_tool "specify-cli" "$SPECKIT_REPO" "specify" "upgrade"
            fi
            ;;
        force)
            install_package "$OPENSPEC_PACKAGE" "openspec" "force"
            if [ "$SKIP_SPECKIT" = false ]; then
                install_uv_tool "specify-cli" "$SPECKIT_REPO" "specify" "force"
            fi
            ;;
    esac

    echo ""
    echo "────────────────────────────────────────"
    echo "完成！"
    echo "────────────────────────────────────────"
    echo ""

    # 显示最终状态
    if [ "$MODE" != "check" ]; then
        print_info "最终状态:"
        local final_openspec=$(get_package_version "openspec")
        local final_speckit=$(get_package_version "specify")
        echo "  openspec: $final_openspec"
        echo "  speckit:  $final_speckit"
        echo ""
    fi

    # 提示下一步
    if [ "$MODE" = "install" ] || [ "$MODE" = "force" ]; then
        print_info "下一步:"
        echo "  运行 'openspec init' 初始化配置"
        echo "  运行 'specify init' 初始化配置"
        echo "  或使用 './refresh.sh' 批量初始化"
    fi

    echo ""
}

main
