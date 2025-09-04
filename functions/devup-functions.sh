#!/usr/bin/env bash
# devup function for both zsh and bash compatibility
# 强制更新 Node.js 本地包并启动开发服务器 | Force update local Node.js package and start dev server
# Compatible with both zsh and bash shells

devup() {
    echo "🔄 开始更新本地包... | Starting to update local package..."
    
    # ==============================================
    # 配置部分 - 可根据需要调整路径（使用默认值即可）
    # Configuration - Adjust paths if needed (default values work for most cases)
    # ==============================================
    
    # 默认配置（适用于 uc-frontend 项目）- Default configuration (for uc-frontend project)
    local package_dir="~/development/uc-frontend/packages/modal--agent-orders.react"
    local app_dir="~/development/uc-frontend/apps/lab"
    local package_name="@uc/modal--agent-orders.react"
    
    # 自定义配置示例 - Custom configuration examples:
    # local package_dir="~/your-project/packages/your-package"
    # local app_dir="~/your-project/apps/your-app"
    # local package_name="@your-org/your-package-name"
    
    # ==============================================
    # 主逻辑 - Main Logic
    # ==============================================
    
    # 记录当前目录
    local current_dir=$(pwd)
    
    # 1. 先到包目录执行 pack
    echo "📦 切换到包目录进行 pack... | Switching to package directory for packing..."
    if [ ! -d "$package_dir" ]; then
        echo "❌ 包目录不存在: $package_dir | Package directory not found: $package_dir"
        echo "   请检查配置中的 package_dir 路径 | Please check the package_dir path in configuration"
        return 1
    fi
    
    cd "$package_dir" || {
        echo "❌ 无法切换到包目录: $package_dir | Failed to switch to package directory: $package_dir"
        return 1
    }
    
    echo "🔨 执行 pnpm pack... | Running pnpm pack..."
    if command -v pnpm >/dev/null 2>&1; then
        if [ -f "./pnpm" ]; then
            ./pnpm pack
        else
            pnpm pack
        fi
    else
        echo "❌ 未找到 pnpm | pnpm not found"
        echo "   请安装 pnpm: npm install -g pnpm | Please install pnpm: npm install -g pnpm"
        return 1
    fi
    
    # 2. 切换回应用目录
    echo "🔄 切换到应用目录... | Switching to app directory..."
    if [ ! -d "$app_dir" ]; then
        echo "❌ 应用目录不存在: $app_dir | App directory not found: $app_dir"
        echo "   请检查配置中的 app_dir 路径 | Please check the app_dir path in configuration"
        return 1
    fi
    
    cd "$app_dir" || {
        echo "❌ 无法切换到应用目录: $app_dir | Failed to switch to app directory: $app_dir"
        return 1
    }
    
    # 3. 移除现有包以确保强制更新
    echo "🗑️  移除现有包... | Removing existing package..."
    if [ -f "./pnpm" ]; then
        ./pnpm remove "$package_name" 2>/dev/null || echo "   (包可能不存在，继续... | Package may not exist, continuing...)"
    else
        pnpm remove "$package_name" 2>/dev/null || echo "   (包可能不存在，继续... | Package may not exist, continuing...)"
    fi
    
    # 4. 查找最新的 tgz 文件（按修改时间排序）
    echo "🔍 查找最新的包文件... | Looking for latest package file..."
    local tgz_file
    if command -v stat >/dev/null 2>&1; then
        # macOS 和 Linux 兼容的文件查找
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            tgz_file=$(find "$package_dir" -name "*.tgz" -type f -exec ls -t {} + 2>/dev/null | head -1)
        else
            # Linux
            tgz_file=$(find "$package_dir" -name "*.tgz" -type f -exec ls -lt {} + 2>/dev/null | head -1 | awk '{print $NF}')
        fi
    else
        # 后备方案
        tgz_file=$(find "$package_dir" -name "*.tgz" -type f 2>/dev/null | head -1)
    fi
    
    if [ -n "$tgz_file" ] && [ -f "$tgz_file" ]; then
        echo "📦 找到最新包文件: $tgz_file | Found latest package file: $tgz_file"
        
        # 显示文件修改时间（兼容 macOS 和 Linux）
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "⏰ 文件修改时间: $(stat -f "%Sm" "$tgz_file") | File modification time: $(stat -f "%Sm" "$tgz_file")"
        elif command -v stat >/dev/null 2>&1; then
            echo "⏰ 文件修改时间: $(stat -c "%y" "$tgz_file" 2>/dev/null || echo "N/A") | File modification time: $(stat -c "%y" "$tgz_file" 2>/dev/null || echo "N/A")"
        fi
        
        # 安装包
        if [ -f "./pnpm" ]; then
            ./pnpm add "$tgz_file"
        else
            pnpm add "$tgz_file"
        fi
    else
        echo "❌ 未找到 .tgz 文件 | No .tgz file found"
        echo "   请确保在包目录中运行过 pnpm pack | Please ensure you have run pnpm pack in the package directory"
        return 1
    fi
    
    echo "🚀 启动开发服务器... | Starting development server..."
    if [ -f "./pnpm" ]; then
        ./pnpm start
    else
        pnpm start
    fi
}

# 配置助手函数 | Configuration helper function
devup_config() {
    echo "🔧 devup 配置助手 | devup Configuration Helper"
    echo ""
    echo "当前配置 | Current Configuration:"
    echo "包目录 | Package Directory: \$package_dir"
    echo "应用目录 | App Directory: \$app_dir" 
    echo "包名称 | Package Name: \$package_name"
    echo ""
    echo "如需修改配置，请编辑此文件: | To modify configuration, please edit this file:"
    echo "$(realpath "${BASH_SOURCE[0]}" 2>/dev/null || echo "devup-functions.sh")"
}

# 使用说明 | Usage Instructions:
# 1. 在 zsh 中: source ~/devup-functions.sh | In zsh: source ~/devup-functions.sh
# 2. 在 bash 中: source ~/devup-functions.sh | In bash: source ~/devup-functions.sh
# 3. 然后使用: devup | Then use: devup
# 4. 配置助手: devup_config | Configuration helper: devup_config
