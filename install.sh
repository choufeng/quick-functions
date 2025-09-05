#!/usr/bin/env bash
# Quick Functions 安装脚本 | Quick Functions Installation Script
# 使用固定目录方案，避免路径问题 | Use fixed directory approach to avoid path issues

set -e  # 遇到错误立即退出 | Exit immediately on error

# 颜色定义 | Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印函数 | Print functions
print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE} Quick Functions 安装程序${NC}"
    echo -e "${BLUE} Quick Functions Installer${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""
}

print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }

print_header

# 安全路径处理 | Safe path handling
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="$HOME"
CURRENT_SHELL="$(basename "$SHELL")"

# 固定安装目录 | Fixed installation directory
INSTALL_DIR="$HOME_DIR/.quick-functions"
FUNCTIONS_DIR="$INSTALL_DIR/functions"
CONFIG_FILE=""

print_info "安装环境信息 | Installation Environment:"
echo "  源目录 | Source Directory: $SCRIPT_DIR"
echo "  安装目录 | Install Directory: $INSTALL_DIR"
echo "  当前 Shell | Current Shell: $CURRENT_SHELL"
echo ""

# 检查源文件 | Check source files
SOURCE_FUNCTIONS_DIR="$SCRIPT_DIR/functions"
if [ ! -d "$SOURCE_FUNCTIONS_DIR" ] || [ ! -f "$SOURCE_FUNCTIONS_DIR/devup-functions.sh" ]; then
    print_error "未找到源函数目录或文件 | Source functions directory or files not found"
    exit 1
fi

# 确定配置文件 | Determine config file
case $CURRENT_SHELL in
    "zsh")  CONFIG_FILE="$HOME_DIR/.zshrc" ;;
    "bash") CONFIG_FILE="$HOME_DIR/.bashrc" ;;
    *)
        print_warning "未识别的 shell: $CURRENT_SHELL | Unrecognized shell: $CURRENT_SHELL"
        echo "请选择要配置的 shell | Please choose shell to configure:"
        echo "1) zsh (.zshrc)  2) bash (.bashrc)  3) 跳过配置 | skip"
        read -p "选择 | Choice (1-3): " choice
        case $choice in
            1) CONFIG_FILE="$HOME_DIR/.zshrc" ;;
            2) CONFIG_FILE="$HOME_DIR/.bashrc" ;;
            *) CONFIG_FILE="" ;;
        esac
        ;;
esac

# 创建安装目录 | Create install directory
print_info "创建安装目录... | Creating install directory..."
mkdir -p "$FUNCTIONS_DIR"

# 复制函数文件 | Copy function files
print_info "复制函数文件... | Copying function files..."
cp -r "$SOURCE_FUNCTIONS_DIR"/* "$FUNCTIONS_DIR/"
print_success "函数文件已安装到: $FUNCTIONS_DIR | Function files installed to: $FUNCTIONS_DIR"

# 创建加载脚本 | Create loader script
LOADER_SCRIPT="$INSTALL_DIR/load.sh"
cat > "$LOADER_SCRIPT" << 'EOF'
#!/usr/bin/env bash
# Quick Functions 加载脚本 | Quick Functions Loader Script
# 自动加载所有函数文件 | Auto load all function files

# 使用固定路径，避免路径解析问题
FUNCTIONS_DIR="$HOME/.quick-functions/functions"

# 加载所有 .sh 文件 | Load all .sh files
if [ -d "$FUNCTIONS_DIR" ]; then
    for func_file in "$FUNCTIONS_DIR"/*.sh; do
        # 检查是否真的存在文件（避免 glob 不匹配的情况）
        if [ -f "$func_file" ]; then
            source "$func_file"
        fi
    done
fi
EOF
chmod +x "$LOADER_SCRIPT"
print_success "加载脚本已创建: $LOADER_SCRIPT | Loader script created: $LOADER_SCRIPT"

# 配置 shell | Configure shell
if [ -n "$CONFIG_FILE" ]; then
    print_info "配置 shell... | Configuring shell..."
    
    # 创建配置文件（如果不存在）
    [ ! -f "$CONFIG_FILE" ] && touch "$CONFIG_FILE"
    
    # 检查是否已配置
    if grep -q "\.quick-functions/load\.sh" "$CONFIG_FILE" 2>/dev/null; then
        print_warning "Quick Functions 已经配置 | Quick Functions already configured"
    else
        # 添加加载配置
        {
            echo ""
            echo "# Quick Functions - Auto added by installer"
            echo "# 快速函数 - 由安装程序自动添加"
            echo "if [ -f \"\$HOME/.quick-functions/load.sh\" ]; then"
            echo "    source \"\$HOME/.quick-functions/load.sh\""
            echo "fi"
        } >> "$CONFIG_FILE"
        
        print_success "配置已添加到: $CONFIG_FILE | Configuration added to: $CONFIG_FILE"
    fi
    
    # 立即加载
    print_info "加载函数... | Loading functions..."
    # shellcheck source=/dev/null
    source "$LOADER_SCRIPT" 2>/dev/null || print_warning "函数加载失败，请重启终端 | Function loading failed, please restart terminal"
fi

# 创建更新脚本 | Create update script
UPDATE_SCRIPT="$INSTALL_DIR/update.sh"
cat > "$UPDATE_SCRIPT" << EOF
#!/usr/bin/env bash
# Quick Functions 更新脚本 | Quick Functions Update Script

echo "🔄 更新 Quick Functions... | Updating Quick Functions..."

# 检查是否在 git 仓库中
if [ -d "$SCRIPT_DIR/.git" ]; then
    echo "📦 从 git 仓库更新... | Updating from git repository..."
    cd "$SCRIPT_DIR"
    git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || echo "⚠️  Git 更新失败 | Git update failed"
    
    # 重新安装
    echo "🔧 重新安装函数... | Reinstalling functions..."
    cp -r "$SCRIPT_DIR/functions"/* "$FUNCTIONS_DIR/"
    
    # 重新生成 load.sh （确保使用最新的修复版本）
    echo "🔄 更新加载脚本... | Updating load script..."
    cat > "$INSTALL_DIR/load.sh" << 'LOAD_EOF'
#!/usr/bin/env bash
# Quick Functions 加载脚本 | Quick Functions Loader Script
# 自动加载所有函数文件 | Auto load all function files

# 使用固定路径，避免路径解析问题
FUNCTIONS_DIR="\$HOME/.quick-functions/functions"

# 加载所有 .sh 文件 | Load all .sh files
if [ -d "\$FUNCTIONS_DIR" ]; then
    for func_file in "\$FUNCTIONS_DIR"/*.sh; do
        # 检查是否真的存在文件（避免 glob 不匹配的情况）
        if [ -f "\$func_file" ]; then
            source "\$func_file"
        fi
    done
fi
LOAD_EOF
    chmod +x "$INSTALL_DIR/load.sh"
    
    echo "✅ 更新完成！| Update completed!"
else
    echo "⚠️  非 git 仓库，请手动重新安装 | Not a git repository, please reinstall manually"
fi
EOF
chmod +x "$UPDATE_SCRIPT"
print_success "更新脚本已创建: $UPDATE_SCRIPT | Update script created: $UPDATE_SCRIPT"

# 显示安装结果 | Show installation results
echo ""
print_success "🎉 安装完成！| Installation completed!"
echo ""
print_info "安装位置 | Installation location:"
echo "  📁 主目录: $INSTALL_DIR | Main directory: $INSTALL_DIR"
echo "  🔧 函数目录: $FUNCTIONS_DIR | Functions directory: $FUNCTIONS_DIR"
echo "  🚀 加载脚本: $LOADER_SCRIPT | Loader script: $LOADER_SCRIPT"
echo ""
print_info "可用命令 | Available commands:"
echo "  devup        - 开发环境更新 | Development environment update"
echo "  devup_config - 配置助手 | Configuration helper"
echo ""
print_info "管理命令 | Management commands:"
echo "  $UPDATE_SCRIPT  - 更新函数 | Update functions"
echo ""

# 测试安装 | Test installation
if command -v devup >/dev/null 2>&1; then
    print_success "✅ devup 命令已可用！| devup command is available!"
    echo "💡 现在可以运行 'devup' 开始使用 | You can now run 'devup' to get started"
else
    print_warning "⚠️  请重启终端或运行以下命令激活: | Please restart terminal or run the following to activate:"
    echo "  source $CONFIG_FILE"
fi

echo ""
print_info "🙏 感谢使用 Quick Functions! | Thank you for using Quick Functions!"
