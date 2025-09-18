#!/usr/bin/env bash
# devup function for both zsh and bash compatibility
# 强制更新 Node.js 本地包并启动开发服务器 | Force update local Node.js package and start dev server
# Compatible with both zsh and bash shells

devup() {
    # 处理参数 | Handle arguments
    local config_name=""
    local show_help=false
    local show_list=false
    local show_config=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --list)
                show_list=true
                shift
                ;;
            --show)
                show_config="${2:-}"
                shift 2
                ;;
            --help|-h)
                show_help=true
                shift
                ;;
            -*)
                config_name="${1#-}"  # Remove leading dash
                shift
                ;;
            *)
                echo "❌ 未知参数: $1 | Unknown argument: $1"
                show_help=true
                shift
                ;;
        esac
    done
    
    # 显示帮助信息 | Show help
    if [ "$show_help" = true ]; then
        echo "📖 devup 使用说明 | devup Usage:"
        echo "  devup                  使用第一个配置 | Use first configuration"
        echo "  devup -<config_name>   使用指定配置 | Use specific configuration"
        echo "  devup --list           列出所有配置 | List all configurations"
        echo "  devup --show [name]    显示配置详情 | Show configuration details"
        echo "  devup --help           显示此帮助 | Show this help"
        return 0
    fi
    
    # 列出所有配置 | List all configurations
    if [ "$show_list" = true ]; then
        _devup_list_configs
        return $?
    fi
    
    # 显示配置详情 | Show configuration details
    if [ -n "$show_config" ]; then
        _devup_show_config "$show_config"
        return $?
    fi
    
    echo "🔄 开始更新本地包... | Starting to update local package..."
    
    # ==============================================
    # 配置加载 - Load Configuration
    # ==============================================
    
    local package_dir app_dir package_name start_command build_command
    if ! _devup_load_config "$config_name" package_dir app_dir package_name start_command build_command; then
        return 1
    fi
    
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
    
    # 清理旧的临时包文件 | Clean up old temporary package files
    echo "🧹 清理旧的 alpha 版本文件... | Cleaning up old alpha version files..."
    local cleanup_count=0
    if command -v find >/dev/null 2>&1; then
        # 查找并计数超过1天的 alpha 版本文件
        cleanup_count=$(find "$package_dir" -name "*-alpha.*.tgz" -type f -mtime +1 2>/dev/null | wc -l | tr -d ' ')
        # 删除超过1天的 alpha 版本文件
        find "$package_dir" -name "*-alpha.*.tgz" -type f -mtime +1 -delete 2>/dev/null || true
        if [ "$cleanup_count" -gt 0 ]; then
            echo "✅ 清理了 $cleanup_count 个旧的 alpha 版本文件 | Cleaned up $cleanup_count old alpha version files"
        else
            echo "💡 没有发现需要清理的旧文件 | No old files found to clean up"
        fi
    else
        echo "⚠️  find 命令不可用，跳过清理步骤 | find command not available, skipping cleanup"
    fi
    
    # 备份和修改版本号以避免缓存问题 | Backup and modify version to avoid cache issues
    echo "🔖 备份并修改 package.json 版本号... | Backing up and modifying package.json version..."
    local timestamp=$(date +%Y%m%d%H%M%S)
    local package_json="$package_dir/package.json"
    
    # 检查 jq 是否可用 | Check if jq is available
    if ! command -v jq >/dev/null 2>&1; then
        echo "❌ 需要安装 jq 来修改 package.json | jq is required to modify package.json"
        echo "   安装命令 | Install command: brew install jq"
        return 1
    fi
    
    # 备份原始 package.json | Backup original package.json
    cp "$package_json" "$package_json.backup" || {
        echo "❌ 无法备份 package.json | Failed to backup package.json"
        return 1
    }
    
    # 读取当前版本号 | Read current version
    local current_version
    current_version=$(jq -r '.version' "$package_json")
    if [ $? -ne 0 ] || [ "$current_version" = "null" ]; then
        echo "❌ 无法读取当前版本号 | Failed to read current version"
        rm -f "$package_json.backup"
        return 1
    fi
    
    # 生成 alpha 版本号 | Generate alpha version
    local alpha_version="${current_version}-alpha.${timestamp}"
    echo "📝 版本号变更: $current_version → $alpha_version | Version change: $current_version → $alpha_version"
    
    # 修改版本号 | Modify version
    jq --arg version "$alpha_version" '.version = $version' "$package_json" > "$package_json.tmp" && mv "$package_json.tmp" "$package_json" || {
        echo "❌ 无法修改版本号 | Failed to modify version"
        mv "$package_json.backup" "$package_json" 2>/dev/null
        return 1
    }
    
    # 执行构建命令 | Execute build command
    if [ -n "$build_command" ] && [ "$build_command" != "null" ]; then
        echo "🏗️  执行构建命令: $build_command | Running build command: $build_command"
        local build_success=false
        eval "$build_command" && build_success=true
        
        # 检查构建是否成功 | Check if build was successful
        if [ "$build_success" = false ]; then
            echo "❌ 构建失败 | Build failed"
            # 恢复原始文件 | Restore original file
            mv "$package_json.backup" "$package_json" 2>/dev/null
            return 1
        fi
        echo "✅ 构建成功 | Build successful"
    else
        echo "⚠️  跳过构建步骤 (未配置构建命令) | Skipping build step (no build command configured)"
    fi
    
    echo "🔨 执行 pnpm pack... | Running pnpm pack..."
    local pack_success=false
    if command -v pnpm >/dev/null 2>&1; then
        if [ -f "./pnpm" ]; then
            ./pnpm pack && pack_success=true
        else
            pnpm pack && pack_success=true
        fi
    else
        echo "❌ 未找到 pnpm | pnpm not found"
        echo "   请安装 pnpm: npm install -g pnpm | Please install pnpm: npm install -g pnpm"
        # 恢复原始文件 | Restore original file
        mv "$package_json.backup" "$package_json" 2>/dev/null
        return 1
    fi
    
    # 恢复原始 package.json | Restore original package.json
    echo "🔄 恢复原始 package.json... | Restoring original package.json..."
    mv "$package_json.backup" "$package_json" || {
        echo "⚠️  警告: 无法恢复原始 package.json | Warning: Failed to restore original package.json"
    }
    
    # 检查 pack 是否成功 | Check if pack was successful
    if [ "$pack_success" = false ]; then
        echo "❌ pnpm pack 执行失败 | pnpm pack failed"
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
    
    # 3. 跳过移除步骤 - pnpm add 会自动覆盖现有包
    echo "⚡ 跳过移除步骤，直接覆盖安装... | Skipping remove step, directly overwriting..."
    echo "   (pnpm add 会自动处理包的更新 | pnpm add will handle package updates automatically)"
    
    # 4. 查找带 alpha 版本号的 tgz 文件
    echo "🔍 查找 alpha 版本包文件... | Looking for alpha version package file..."
    local tgz_file
    
    # 首先尝试查找带当前时间戳的 alpha 版本文件
    tgz_file=$(find "$package_dir" -name "*-alpha.${timestamp}.tgz" -type f 2>/dev/null | head -1)
    
    # 如果没找到，则查找最新的 alpha 版本文件
    if [ -z "$tgz_file" ] || [ ! -f "$tgz_file" ]; then
        echo "⚠️  未找到当前时间戳的文件，查找最新 alpha 版本... | Current timestamp file not found, looking for latest alpha version..."
        if command -v stat >/dev/null 2>&1; then
            # macOS 和 Linux 兼容的文件查找
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # macOS - 查找最新的 alpha 版本文件
                tgz_file=$(find "$package_dir" -name "*-alpha.*.tgz" -type f -exec ls -t {} + 2>/dev/null | head -1)
            else
                # Linux - 查找最新的 alpha 版本文件
                tgz_file=$(find "$package_dir" -name "*-alpha.*.tgz" -type f -exec ls -lt {} + 2>/dev/null | head -1 | awk '{print $NF}')
            fi
        else
            # 后备方案
            tgz_file=$(find "$package_dir" -name "*-alpha.*.tgz" -type f 2>/dev/null | head -1)
        fi
    fi
    
    # 如果仍然没找到 alpha 版本，则查找任意 tgz 文件作为最后的后备方案
    if [ -z "$tgz_file" ] || [ ! -f "$tgz_file" ]; then
        echo "⚠️  未找到 alpha 版本文件，查找任意包文件... | Alpha version not found, looking for any package file..."
        if command -v stat >/dev/null 2>&1; then
            if [[ "$OSTYPE" == "darwin"* ]]; then
                tgz_file=$(find "$package_dir" -name "*.tgz" -type f -exec ls -t {} + 2>/dev/null | head -1)
            else
                tgz_file=$(find "$package_dir" -name "*.tgz" -type f -exec ls -lt {} + 2>/dev/null | head -1 | awk '{print $NF}')
            fi
        else
            tgz_file=$(find "$package_dir" -name "*.tgz" -type f 2>/dev/null | head -1)
        fi
    fi
    
    if [ -n "$tgz_file" ] && [ -f "$tgz_file" ]; then
        echo "📦 找到最新包文件: $tgz_file | Found latest package file: $tgz_file"
        
        # 显示文件修改时间（兼容 macOS 和 Linux）
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "⏰ 文件修改时间: $(stat -f "%Sm" "$tgz_file") | File modification time: $(stat -f "%Sm" "$tgz_file")"
        elif command -v stat >/dev/null 2>&1; then
            echo "⏰ 文件修改时间: $(stat -c "%y" "$tgz_file" 2>/dev/null || echo "N/A") | File modification time: $(stat -c "%y" "$tgz_file" 2>/dev/null || echo "N/A")"
        fi
        
        # 强制安装包（使用配置中的包名和 package@file:path 格式避免旧路径验证）| Force install package using package name from config and package@file:path format to avoid old path validation
        echo "🚀 强制安装 alpha 版本包: $package_name | Force installing alpha version package: $package_name"
        local install_success=false
        if [ -f "./pnpm" ]; then
            ./pnpm add "${package_name}@file:${tgz_file}" --force && install_success=true
        else
            pnpm add "${package_name}@file:${tgz_file}" --force && install_success=true
        fi
        
        # 安装成功后立即清理当前包文件 | Clean up current package file after successful installation
        if [ "$install_success" = true ] && [ -f "$tgz_file" ]; then
            echo "🧹 清理当前包文件: $(basename "$tgz_file") | Cleaning up current package file: $(basename "$tgz_file")"
            rm -f "$tgz_file" || {
                echo "⚠️  警告: 无法删除包文件 $tgz_file | Warning: Failed to delete package file $tgz_file"
            }
        elif [ "$install_success" = false ]; then
            echo "❌ 包安装失败，保留包文件用于调试 | Package installation failed, keeping package file for debugging"
            return 1
        fi
    else
        echo "❌ 未找到 .tgz 文件 | No .tgz file found"
        echo "   请确保在包目录中运行过 pnpm pack | Please ensure you have run pnpm pack in the package directory"
        return 1
    fi
    
    echo "🚀 启动开发服务器... | Starting development server..."
    echo "📝 使用启动命令: $start_command | Using start command: $start_command"
    eval "$start_command"
}

# 配置助手函数 | Configuration helper function
devup_config() {
    # 获取默认配置值
    local package_dir="$HOME/development/uc-frontend/packages/modal--agent-orders.react"
    local app_dir="$HOME/development/uc-frontend/apps/lab"
    local package_name="@uc/modal--agent-orders.react"
    
    echo "🔧 devup 配置助手 | devup Configuration Helper"
    echo ""
    echo "当前配置 | Current Configuration:"
    echo "包目录 | Package Directory: $package_dir"
    echo "应用目录 | App Directory: $app_dir" 
    echo "包名称 | Package Name: $package_name"
    echo ""
    
    # 检查路径是否存在
    if [ -d "$package_dir" ]; then
        echo "✅ 包目录存在 | Package directory exists"
    else
        echo "❌ 包目录不存在 | Package directory not found"
    fi
    
    if [ -d "$app_dir" ]; then
        echo "✅ 应用目录存在 | App directory exists"
    else
        echo "❌ 应用目录不存在 | App directory not found"
    fi
    
    echo ""
    echo "如需修改配置，请编辑此文件: | To modify configuration, please edit this file:"
    echo "$(realpath "${BASH_SOURCE[0]}" 2>/dev/null || echo "devup-functions.sh")"
}

# ==============================================
# 配置管理辅助函数 | Configuration Management Helper Functions
# ==============================================

# 加载配置 | Load configuration
_devup_load_config() {
    local requested_config_name="$1"
    local pkg_dir_ref_name="$2"
    local app_dir_ref_name="$3" 
    local pkg_name_ref_name="$4"
    local start_cmd_ref_name="$5"
    local build_cmd_ref_name="$6"
    
    local config_file="$HOME/.quick-functions/devup-configs.json"
    
    # 如果配置文件不存在，使用默认配置 | Use default config if file doesn't exist
    if [ ! -f "$config_file" ]; then
        echo "⚠️  配置文件不存在，使用默认配置 | Config file not found, using default config"
        eval "$pkg_dir_ref_name='$HOME/development/uc-frontend/packages/modal--agent-orders.react'"
        eval "$app_dir_ref_name='$HOME/development/uc-frontend/apps/lab'"
        eval "$pkg_name_ref_name='@uc/modal--agent-orders.react'"
        [ -n "$start_cmd_ref_name" ] && eval "$start_cmd_ref_name='./pnpm start'"
        [ -n "$build_cmd_ref_name" ] && eval "$build_cmd_ref_name='./pnpm run build'"
        return 0
    fi
    
    # 检查 jq 是否可用 | Check if jq is available
    if ! command -v jq >/dev/null 2>&1; then
        echo "❌ 需要安装 jq 来解析配置文件 | jq is required to parse config file"
        echo "   安装命令 | Install command: brew install jq"
        return 1
    fi
    
    # 读取配置数组长度 | Read config array length
    local config_count
    config_count=$(jq '.configs | length' "$config_file" 2>/dev/null)
    if [ $? -ne 0 ] || [ "$config_count" = "null" ] || [ "$config_count" -eq 0 ]; then
        echo "❌ 配置文件格式错误或为空 | Config file format error or empty"
        return 1
    fi
    
    local config_index=0
    
    # 如果指定了配置名称，查找对应的配置 | Find config by name if specified
    if [ -n "$requested_config_name" ]; then
        local found=false
        for ((i=0; i<config_count; i++)); do
            local name
            name=$(jq -r ".configs[$i].name" "$config_file" 2>/dev/null)
            if [ "$name" = "$requested_config_name" ]; then
                config_index=$i
                found=true
                break
            fi
        done
        
        if [ "$found" = false ]; then
            echo "❌ 找不到配置: $requested_config_name | Config not found: $requested_config_name"
            echo "📋 可用配置 | Available configs:"
            _devup_list_configs
            return 1
        fi
    fi
    
    # 加载配置数据 | Load config data
    local config_data
    config_data=$(jq -r ".configs[$config_index]" "$config_file" 2>/dev/null)
    if [ $? -ne 0 ] || [ "$config_data" = "null" ]; then
        echo "❌ 无法读取配置数据 | Unable to read config data"
        return 1
    fi
    
    # 提取配置值并展开环境变量 | Extract config values and expand environment variables
    # 注意：避免与调用方变量同名，防止作用域遮蔽 | Avoid name shadowing with caller variables
    local _package_dir _app_dir _package_name _start_command _build_command _config_name_actual
    _package_dir=$(echo "$config_data" | jq -r '.package_dir' | envsubst)
    _app_dir=$(echo "$config_data" | jq -r '.app_dir' | envsubst)
    _package_name=$(echo "$config_data" | jq -r '.package_name')
    _start_command=$(echo "$config_data" | jq -r '.start_command // "./pnpm start"')  # Default fallback
    _build_command=$(echo "$config_data" | jq -r '.build_command // "./pnpm run build"')  # Default fallback
    _config_name_actual=$(echo "$config_data" | jq -r '.name')
    
    if [ "$_package_dir" = "null" ] || [ "$_app_dir" = "null" ] || [ "$_package_name" = "null" ]; then
        echo "❌ 配置数据不完整 | Incomplete config data"
        return 1
    fi
    
    # 设置返回值 | Set return values (write to variables in caller scope)
    eval "$pkg_dir_ref_name='$_package_dir'"
    eval "$app_dir_ref_name='$_app_dir'"
    eval "$pkg_name_ref_name='$_package_name'"
    [ -n "$start_cmd_ref_name" ] && eval "$start_cmd_ref_name='$_start_command'"
    [ -n "$build_cmd_ref_name" ] && eval "$build_cmd_ref_name='$_build_command'"
    
    echo "📝 使用配置: $_config_name_actual | Using config: $_config_name_actual"
    return 0
}

# 列出所有配置 | List all configurations
_devup_list_configs() {
    local config_file="$HOME/.quick-functions/devup-configs.json"
    
    if [ ! -f "$config_file" ]; then
        echo "❌ 配置文件不存在: $config_file | Config file not found: $config_file"
        return 1
    fi
    
    if ! command -v jq >/dev/null 2>&1; then
        echo "❌ 需要安装 jq 来解析配置文件 | jq is required to parse config file"
        echo "   安装命令 | Install command: brew install jq"
        return 1
    fi
    
    echo "📋 可用配置列表 | Available Configurations:"
    echo ""
    
    local config_count
    config_count=$(jq '.configs | length' "$config_file" 2>/dev/null)
    if [ $? -ne 0 ] || [ "$config_count" = "null" ] || [ "$config_count" -eq 0 ]; then
        echo "❌ 配置文件格式错误或为空 | Config file format error or empty"
        return 1
    fi
    
    for ((i=0; i<config_count; i++)); do
        local name description
        name=$(jq -r ".configs[$i].name" "$config_file" 2>/dev/null)
        description=$(jq -r ".configs[$i].description" "$config_file" 2>/dev/null)
        
        if [ $i -eq 0 ]; then
            echo "  🔹 $name (默认 | default) - $description"
        else
            echo "  🔸 $name - $description"
        fi
        echo "     使用方式 | Usage: devup -$name"
    done
    
    echo ""
    echo "💡 提示 | Tip: 使用 'devup --show <config_name>' 查看配置详情 | Use 'devup --show <config_name>' for details"
}

# 显示配置详情 | Show configuration details
_devup_show_config() {
    local config_name="$1"
    local config_file="$HOME/.quick-functions/devup-configs.json"
    
    if [ ! -f "$config_file" ]; then
        echo "❌ 配置文件不存在: $config_file | Config file not found: $config_file"
        return 1
    fi
    
    if ! command -v jq >/dev/null 2>&1; then
        echo "❌ 需要安装 jq 来解析配置文件 | jq is required to parse config file"
        echo "   安装命令 | Install command: brew install jq"
        return 1
    fi
    
    # 如果没有指定配置名，显示第一个配置 | Show first config if no name specified
    if [ -z "$config_name" ]; then
        config_name=$(jq -r '.configs[0].name' "$config_file" 2>/dev/null)
        if [ "$config_name" = "null" ]; then
            echo "❌ 没有可用配置 | No available configurations"
            return 1
        fi
        echo "💡 显示默认配置 | Showing default configuration"
    fi
    
    # 查找配置 | Find configuration
    local config_count
    config_count=$(jq '.configs | length' "$config_file" 2>/dev/null)
    if [ $? -ne 0 ] || [ "$config_count" = "null" ] || [ "$config_count" -eq 0 ]; then
        echo "❌ 配置文件格式错误或为空 | Config file format error or empty"
        return 1
    fi
    
    local found=false
    for ((i=0; i<config_count; i++)); do
        local name
        name=$(jq -r ".configs[$i].name" "$config_file" 2>/dev/null)
        if [ "$name" = "$config_name" ]; then
            found=true
            echo "📝 配置详情 | Configuration Details: $config_name"
            echo ""
            
            local description package_dir app_dir package_name start_command build_command
            description=$(jq -r ".configs[$i].description" "$config_file")
            package_dir=$(jq -r ".configs[$i].package_dir" "$config_file" | envsubst)
            app_dir=$(jq -r ".configs[$i].app_dir" "$config_file" | envsubst) 
            package_name=$(jq -r ".configs[$i].package_name" "$config_file")
            start_command=$(jq -r ".configs[$i].start_command // \"./pnpm start\"" "$config_file")
            build_command=$(jq -r ".configs[$i].build_command // \"./pnpm run build\"" "$config_file")
            
            echo "  描述 | Description: $description"
            echo "  包目录 | Package Directory: $package_dir"
            echo "  应用目录 | App Directory: $app_dir"
            echo "  包名称 | Package Name: $package_name"
            echo "  启动命令 | Start Command: $start_command"
            echo "  构建命令 | Build Command: $build_command"
            echo ""
            
            # 检查路径是否存在 | Check if paths exist
            if [ -d "$package_dir" ]; then
                echo "  ✅ 包目录存在 | Package directory exists"
            else
                echo "  ❌ 包目录不存在 | Package directory not found"
            fi
            
            if [ -d "$app_dir" ]; then
                echo "  ✅ 应用目录存在 | App directory exists"
            else
                echo "  ❌ 应用目录不存在 | App directory not found"
            fi
            
            echo ""
            echo "  使用方式 | Usage: devup -$config_name"
            break
        fi
    done
    
    if [ "$found" = false ]; then
        echo "❌ 找不到配置: $config_name | Config not found: $config_name"
        echo "📋 可用配置 | Available configs:"
        _devup_list_configs
        return 1
    fi
}

# 使用说明 | Usage Instructions:
# 1. 在 zsh 中: source ~/devup-functions.sh | In zsh: source ~/devup-functions.sh
# 2. 在 bash 中: source ~/devup-functions.sh | In bash: source ~/devup-functions.sh
# 3. 然后使用: devup | Then use: devup
# 4. 配置助手: devup_config | Configuration helper: devup_config
# 5. 重新加载: devup_reload | Reload functions: devup_reload
# 6. 新功能 | New features:
#    - devup -<config_name>   使用指定配置 | Use specific configuration
#    - devup --list           列出所有配置 | List all configurations
#    - devup --show [name]    显示配置详情 | Show configuration details
#
# 📝 缓存问题解决方案 | Cache Issue Solutions:
# - 在 pack 前临时修改 package.json 版本号为 alpha 版本 | Temporarily modify package.json version to alpha before pack
# - 使用时间戳确保每次版本号都不同 (如: 5.2.1-alpha.20250202010102) | Use timestamp to ensure unique version each time
# - pack 前自动执行构建命令确保最新代码 | Auto-execute build command before pack to ensure latest code
# - pack 完成后立即恢复原始 package.json | Restore original package.json immediately after pack
# - 使用 package@file:path 格式安装避免旧路径验证 | Use package@file:path format to avoid old path validation
# - 强制安装参数 --force 确保覆盖缓存 | Force install with --force to override cache
# - 需要 jq 工具来安全地修改 JSON 文件 | Requires jq tool for safe JSON modification
# - 可使用 devup_reload 重新加载函数 | Use devup_reload to refresh functions
#
# 🧹 文件清理机制 | File Cleanup Mechanism:
# - 每次运行前自动清理超过1天的旧 alpha 版本文件 | Auto-cleanup alpha version files older than 1 day before each run
# - 包安装成功后立即删除当前使用的包文件 | Immediately delete current package file after successful installation
# - 安装失败时保留包文件用于调试 | Keep package file for debugging when installation fails
# - 防止 .tgz 文件在包目录中无限累积 | Prevents unlimited accumulation of .tgz files in package directory
#
# 📋 配置文件示例 | Configuration File Example:
# {
#   "configs": [
#     {
#       "name": "modal-orders",
#       "description": "Modal Orders React Package",
#       "package_dir": "$HOME/development/uc-frontend/packages/modal--agent-orders.react",
#       "app_dir": "$HOME/development/uc-frontend/apps/lab",
#       "package_name": "@uc/modal--agent-orders.react",
#       "start_command": "./pnpm start",
#       "build_command": "./pnpm run build"
#     }
#   ]
# }
#
# 💡 构建命令配置 | Build Command Configuration:
# - build_command 为可选字段，默认值: "./pnpm run build" | build_command is optional, default: "./pnpm run build"
# - 设置为空字符串 "" 可跳过构建步骤 | Set to empty string "" to skip build step
# - 支持任意自定义构建命令 | Supports any custom build command
