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
    local show_chain=""
    local validate_chain=""
    local chain_file=""

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
            --show-chain)
                show_chain="${2:-}"
                shift 2
                ;;
            --validate-chain)
                validate_chain="${2:-}"
                shift 2
                ;;
            --chain)
                chain_file="${2:-}"
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
        echo "  devup                     使用第一个配置 | Use first configuration"
        echo "  devup -<config_name>      使用指定配置 | Use specific configuration"
        echo "  devup --chain <file>      使用独立链式配置文件 | Use standalone chain config file"
        echo "  devup --list              列出所有配置 | List all configurations"
        echo "  devup --show [name]       显示配置详情 | Show configuration details"
        echo "  devup --show-chain <file> 显示链式配置详情 | Show chain configuration details"
        echo "  devup --validate-chain <file> 验证链式配置文件 | Validate chain configuration file"
        echo "  devup --help              显示此帮助 | Show this help"
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

    # 显示链式配置详情 | Show chain configuration details
    if [ -n "$show_chain" ]; then
        _devup_show_chain_config "$show_chain"
        return $?
    fi

    # 验证链式配置文件 | Validate chain configuration file
    if [ -n "$validate_chain" ]; then
        _devup_validate_chain_config "$validate_chain"
        return $?
    fi

    # 使用独立链式配置文件 | Use standalone chain config file
    if [ -n "$chain_file" ]; then
        _devup_run_with_chain_file "$chain_file"
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

# === STREAM A: Configuration Type Detection ===
# 验证链式配置格式 | Validate chain configuration format
_validate_chain_config() {
    local config_data="$1"
    
    # 检查 type 字段是否为 "chain" | Check if type field is "chain"
    local config_type
    config_type=$(echo "$config_data" | jq -r '.type // "legacy"')
    if [ "$config_type" != "chain" ]; then
        echo "❌ 配置类型错误，期望 'chain'，实际 '$config_type' | Invalid config type, expected 'chain', got '$config_type'"
        return 1
    fi
    
    # 检查 chain 数组是否存在 | Check if chain array exists
    local chain_data
    chain_data=$(echo "$config_data" | jq '.chain')
    if [ "$chain_data" = "null" ]; then
        echo "❌ 链式配置缺少 'chain' 数组 | Chain config missing 'chain' array"
        return 1
    fi
    
    # 检查 chain 数组是否为空 | Check if chain array is empty
    local chain_length
    chain_length=$(echo "$config_data" | jq '.chain | length')
    if [ "$chain_length" -eq 0 ]; then
        echo "❌ 链式配置的 'chain' 数组不能为空 | Chain config 'chain' array cannot be empty"
        return 1
    fi
    
    # 验证每个链节点的必需字段 | Validate required fields for each chain node
    for ((i=0; i<chain_length; i++)); do
        local node_data
        node_data=$(echo "$config_data" | jq ".chain[$i]")
        
        # 检查节点类型 | Check node type
        local node_type
        node_type=$(echo "$node_data" | jq -r '.type')
        if [ "$node_type" = "null" ]; then
            echo "❌ 链节点 [$i] 缺少 'type' 字段 | Chain node [$i] missing 'type' field"
            return 1
        fi
        
        if [ "$node_type" != "package" ] && [ "$node_type" != "app" ]; then
            echo "❌ 链节点 [$i] 类型无效: '$node_type'，只支持 'package' 或 'app' | Chain node [$i] invalid type: '$node_type', only 'package' or 'app' supported"
            return 1
        fi
        
        # 检查节点名称 | Check node name
        local node_name
        node_name=$(echo "$node_data" | jq -r '.name')
        if [ "$node_name" = "null" ] || [ -z "$node_name" ]; then
            echo "❌ 链节点 [$i] 缺少 'name' 字段 | Chain node [$i] missing 'name' field"
            return 1
        fi
        
        # 根据节点类型检查必需字段 | Check required fields based on node type
        if [ "$node_type" = "package" ]; then
            local package_dir package_name
            package_dir=$(echo "$node_data" | jq -r '.package_dir')
            package_name=$(echo "$node_data" | jq -r '.package_name')
            
            if [ "$package_dir" = "null" ] || [ -z "$package_dir" ]; then
                echo "❌ 包节点 [$i] '$node_name' 缺少 'package_dir' 字段 | Package node [$i] '$node_name' missing 'package_dir' field"
                return 1
            fi
            
            if [ "$package_name" = "null" ] || [ -z "$package_name" ]; then
                echo "❌ 包节点 [$i] '$node_name' 缺少 'package_name' 字段 | Package node [$i] '$node_name' missing 'package_name' field"
                return 1
            fi
        elif [ "$node_type" = "app" ]; then
            local app_dir
            app_dir=$(echo "$node_data" | jq -r '.app_dir')
            
            if [ "$app_dir" = "null" ] || [ -z "$app_dir" ]; then
                echo "❌ 应用节点 [$i] '$node_name' 缺少 'app_dir' 字段 | App node [$i] '$node_name' missing 'app_dir' field"
                return 1
            fi
        fi
    done
    
    echo "✅ 链式配置验证通过 | Chain config validation passed"
    return 0
}

# === STREAM B: Chain Config Parser ===
# 解析链式配置数据 | Parse chain configuration data
_parse_chain_config() {
    local config_data="$1"
    local result_ref_name="$2"  # 用于返回解析结果的变量名 | Variable name for returning parsed result
    
    # 获取链数组长度 | Get chain array length
    local chain_length
    chain_length=$(echo "$config_data" | jq '.chain | length')
    
    echo "🔗 开始解析链式配置，包含 $chain_length 个节点 | Starting to parse chain config with $chain_length nodes"
    
    # 初始化解析结果数组 | Initialize parsed result array
    local parsed_nodes=()
    local node_names=()
    
    # 逐个解析链节点 | Parse each chain node
    for ((i=0; i<chain_length; i++)); do
        local node_data
        node_data=$(echo "$config_data" | jq ".chain[$i]")
        
        # 提取基本信息 | Extract basic information
        local node_type node_name
        node_type=$(echo "$node_data" | jq -r '.type')
        node_name=$(echo "$node_data" | jq -r '.name')
        
        echo "  📦 解析节点 [$i]: $node_name (类型: $node_type) | Parsing node [$i]: $node_name (type: $node_type)"
        
        # 根据节点类型解析特定字段 | Parse specific fields based on node type
        local parsed_node=""
        if [ "$node_type" = "package" ]; then
            local package_dir package_name build_command
            # 展开环境变量 | Expand environment variables
            package_dir=$(echo "$node_data" | jq -r '.package_dir' | envsubst)
            package_name=$(echo "$node_data" | jq -r '.package_name')
            build_command=$(echo "$node_data" | jq -r '.build_command // "./pnpm run build"')
            
            # 构建解析后的节点数据 | Build parsed node data
            parsed_node=$(jq -n \
                --arg type "$node_type" \
                --arg name "$node_name" \
                --arg package_dir "$package_dir" \
                --arg package_name "$package_name" \
                --arg build_command "$build_command" \
                '{
                    type: $type,
                    name: $name,
                    package_dir: $package_dir,
                    package_name: $package_name,
                    build_command: $build_command
                }')
                
        elif [ "$node_type" = "app" ]; then
            local app_dir start_command
            # 展开环境变量 | Expand environment variables
            app_dir=$(echo "$node_data" | jq -r '.app_dir' | envsubst)
            start_command=$(echo "$node_data" | jq -r '.start_command // "./pnpm start"')
            
            # 构建解析后的节点数据 | Build parsed node data
            parsed_node=$(jq -n \
                --arg type "$node_type" \
                --arg name "$node_name" \
                --arg app_dir "$app_dir" \
                --arg start_command "$start_command" \
                '{
                    type: $type,
                    name: $name,
                    app_dir: $app_dir,
                    start_command: $start_command
                }')
        fi
        
        # 处理依赖关系 | Process dependencies
        local dependencies_json
        dependencies_json=$(echo "$node_data" | jq '.dependencies // []')
        parsed_node=$(echo "$parsed_node" | jq --argjson deps "$dependencies_json" '. + {dependencies: $deps}')
        
        # 保存解析后的节点 | Save parsed node
        parsed_nodes+=("$parsed_node")
        node_names+=("$node_name")
        
        echo "    ✅ 节点 $node_name 解析完成 | Node $node_name parsed successfully"
    done
    
    # 验证依赖关系引用的有效性 | Validate dependency references
    echo "🔍 验证依赖关系... | Validating dependencies..."
    for ((i=0; i<chain_length; i++)); do
        local node_name="${node_names[i]}"
        local node_json="${parsed_nodes[i]}"
        local dependencies
        dependencies=$(echo "$node_json" | jq -r '.dependencies[]?' 2>/dev/null)
        
        if [ -n "$dependencies" ]; then
            echo "$dependencies" | while IFS= read -r dep_name; do
                # 检查依赖是否在已知节点列表中 | Check if dependency exists in known nodes
                local found=false
                for known_name in "${node_names[@]}"; do
                    if [ "$known_name" = "$dep_name" ]; then
                        found=true
                        break
                    fi
                done
                
                if [ "$found" = false ]; then
                    echo "❌ 节点 '$node_name' 引用了未知的依赖: '$dep_name' | Node '$node_name' references unknown dependency: '$dep_name'"
                    return 1
                fi
                
                # 检查是否存在循环依赖 (简单检查：依赖不能指向后面的节点) | Check for circular dependencies (simple check: dependency cannot point to later nodes)
                local dep_index=-1
                for ((j=0; j<${#node_names[@]}; j++)); do
                    if [ "${node_names[j]}" = "$dep_name" ]; then
                        dep_index=$j
                        break
                    fi
                done
                
                if [ "$dep_index" -ge "$i" ]; then
                    echo "❌ 检测到无效的依赖顺序: 节点 '$node_name' (位置$i) 不能依赖位置 $dep_index 的节点 '$dep_name' | Invalid dependency order detected: node '$node_name' (position $i) cannot depend on node '$dep_name' at position $dep_index"
                    return 1
                fi
                
                echo "    ✅ 依赖关系验证通过: $node_name -> $dep_name | Dependency validation passed: $node_name -> $dep_name"
            done
        fi
    done
    
    # 构建最终的解析结果 | Build final parsed result
    local final_result
    final_result=$(jq -n \
        --argjson nodes "$(printf '%s\n' "${parsed_nodes[@]}" | jq -s '.')" \
        --argjson node_count "$chain_length" \
        '{
            type: "chain",
            node_count: $node_count,
            nodes: $nodes
        }')
    
    # 通过引用返回结果 | Return result via reference
    eval "$result_ref_name='$final_result'"
    
    echo "✅ 链式配置解析完成，共 $chain_length 个节点 | Chain config parsing completed with $chain_length nodes"
    return 0
}

# === STREAM C: API Integration ===
# 加载配置 | Load configuration
# API 签名：支持链式配置和向后兼容性 | API signature: supports chain configs and backward compatibility
# 用法 | Usage:
#   单包模式 | Single package mode: _devup_load_config "config_name" pkg_dir app_dir pkg_name [start_cmd] [build_cmd]
#   链式模式 | Chain mode: _devup_load_config "config_name" pkg_dir app_dir pkg_name [start_cmd] [build_cmd] [chain_result_ref] [config_type_ref]
_devup_load_config() {
    local requested_config_name="$1"
    local pkg_dir_ref_name="$2"
    local app_dir_ref_name="$3" 
    local pkg_name_ref_name="$4"
    local start_cmd_ref_name="$5"
    local build_cmd_ref_name="$6"
    local chain_result_ref_name="$7"  # 新增：链式配置完整结果 | New: complete chain config result
    local config_type_ref_name="$8"   # 新增：配置类型返回 | New: config type return
    
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
    
    # === STREAM A: Configuration Type Detection ===
    # 检测配置类型 | Detect configuration type
    local config_type
    config_type=$(echo "$config_data" | jq -r '.type // "legacy"')
    
    if [ "$config_type" = "chain" ]; then
        # 链式配置：验证格式并委托给链式配置处理器 | Chain config: validate format and delegate to chain handler
        echo "🔗 检测到链式配置，正在验证... | Chain configuration detected, validating..."
        if ! _validate_chain_config "$config_data"; then
            return 1
        fi
        
        # === STREAM B: Chain Config Parser Integration ===
        # 调用链式配置解析器 | Call chain config parser
        local parsed_chain_result
        if ! _parse_chain_config "$config_data" "parsed_chain_result"; then
            echo "❌ 链式配置解析失败 | Chain config parsing failed"
            return 1
        fi
        
        # === STREAM C: 链式配置完整API实现 | Chain Config Complete API Implementation ===
        echo "✅ 链式配置解析成功 | Chain config parsing successful"
        
        # 返回配置类型 | Return config type
        if [ -n "$config_type_ref_name" ]; then
            eval "$config_type_ref_name='chain'"
            echo "🏷️  配置类型已设置: chain | Config type set: chain"
        fi
        
        # 返回完整的链式配置结果 | Return complete chain config result
        if [ -n "$chain_result_ref_name" ]; then
            eval "$chain_result_ref_name='$parsed_chain_result'"
            local node_count
            node_count=$(echo "$parsed_chain_result" | jq '.node_count')
            echo "📊 链式配置完整结果已返回，包含 $node_count 个节点 | Complete chain config result returned with $node_count nodes"
        fi
        
        # 为向后兼容性，智能选择合适的节点返回基本信息 | For backward compatibility, intelligently select appropriate node for basic info
        local selected_node selected_node_type
        
        # 优先选择第一个包节点，如果没有则选择第一个应用节点 | Prefer first package node, fallback to first app node
        local node_count
        node_count=$(echo "$parsed_chain_result" | jq '.node_count')
        
        if [ "$node_count" -eq 0 ]; then
            echo "❌ 错误：链式配置中没有节点 | Error: No nodes in chain config"
            return 1
        fi
        
        echo "🔍 在 $node_count 个节点中选择主要节点... | Selecting primary node from $node_count nodes..."
        
        for ((i=0; i<node_count; i++)); do
            local node_data node_type node_name
            node_data=$(echo "$parsed_chain_result" | jq ".nodes[$i]")
            node_type=$(echo "$node_data" | jq -r '.type')
            node_name=$(echo "$node_data" | jq -r '.name')
            
            if [ "$node_type" = "package" ]; then
                selected_node="$node_data"
                selected_node_type="package"
                echo "📦 选择包节点 '$node_name' (位置 $((i+1))) 作为主要节点 | Selected package node '$node_name' (position $((i+1))) as primary node"
                break
            fi
        done
        
        # 如果没有找到包节点，使用第一个应用节点 | If no package node found, use first app node
        if [ -z "$selected_node" ]; then
            selected_node=$(echo "$parsed_chain_result" | jq '.nodes[0]')
            selected_node_type=$(echo "$selected_node" | jq -r '.type')
            local first_node_name
            first_node_name=$(echo "$selected_node" | jq -r '.name')
            echo "🏗️  使用应用节点 '$first_node_name' 作为主要节点 | Using app node '$first_node_name' as primary node"
        fi
        
        # 根据选中的节点类型设置返回值 | Set return values based on selected node type
        if [ "$selected_node_type" = "package" ]; then
            local _package_dir _package_name _build_command
            _package_dir=$(echo "$selected_node" | jq -r '.package_dir')
            _package_name=$(echo "$selected_node" | jq -r '.package_name')
            _build_command=$(echo "$selected_node" | jq -r '.build_command')
            
            # 验证提取的数据 | Validate extracted data
            if [ "$_package_dir" = "null" ] || [ -z "$_package_dir" ]; then
                echo "❌ 错误：选择的包节点缺少 package_dir | Error: Selected package node missing package_dir"
                return 1
            fi
            if [ "$_package_name" = "null" ] || [ -z "$_package_name" ]; then
                echo "❌ 错误：选择的包节点缺少 package_name | Error: Selected package node missing package_name"
                return 1
            fi
            
            eval "$pkg_dir_ref_name='$_package_dir'"
            eval "$pkg_name_ref_name='$_package_name'"
            [ -n "$build_cmd_ref_name" ] && eval "$build_cmd_ref_name='$_build_command'"
            
            echo "✅ 向后兼容：返回包节点信息 | Backward compatibility: returning package node info"
            echo "   📁 包目录: $_package_dir | Package directory: $_package_dir"
            echo "   📦 包名称: $_package_name | Package name: $_package_name"
            
        elif [ "$selected_node_type" = "app" ]; then
            local _app_dir _start_command
            _app_dir=$(echo "$selected_node" | jq -r '.app_dir')
            _start_command=$(echo "$selected_node" | jq -r '.start_command')
            
            # 验证提取的数据 | Validate extracted data
            if [ "$_app_dir" = "null" ] || [ -z "$_app_dir" ]; then
                echo "❌ 错误：选择的应用节点缺少 app_dir | Error: Selected app node missing app_dir"
                return 1
            fi
            
            eval "$app_dir_ref_name='$_app_dir'"
            [ -n "$start_cmd_ref_name" ] && eval "$start_cmd_ref_name='$_start_command'"
            
            echo "✅ 向后兼容：返回应用节点信息 | Backward compatibility: returning app node info"
            echo "   📁 应用目录: $_app_dir | App directory: $_app_dir"
            
        else
            echo "❌ 错误：未知的节点类型 '$selected_node_type' | Error: Unknown node type '$selected_node_type'"
            return 1
        fi
        
        return 0
        
    elif [ "$config_type" = "legacy" ]; then
        # 传统单包配置：继续现有逻辑 | Legacy single package config: continue with existing logic
        echo "📦 使用传统单包配置模式 | Using legacy single package config mode"
        
        # 返回配置类型 | Return config type
        if [ -n "$config_type_ref_name" ]; then
            eval "$config_type_ref_name='legacy'"
            echo "🏷️  配置类型已设置: legacy | Config type set: legacy"
        fi
        
        # 为链式配置API提供空值 | Provide empty values for chain config API
        [ -n "$chain_result_ref_name" ] && eval "$chain_result_ref_name=''"
    else
        # 未知配置类型 | Unknown config type
        echo "❌ 未知的配置类型: '$config_type'，支持的类型: 'chain' 或留空(默认单包模式) | Unknown config type: '$config_type', supported types: 'chain' or empty (default single package mode)"
        return 1
    fi
    
    # 传统单包配置处理逻辑 | Legacy single package config processing logic
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
    
    # 为链式配置API提供空值 | Provide empty values for chain config API
    [ -n "$chain_result_ref_name" ] && eval "$chain_result_ref_name=''"
    
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

# 显示链式配置详情 | Show chain configuration details
_devup_show_chain_config() {
    local chain_file="$1"

    if [ -z "$chain_file" ]; then
        echo "❌ 请提供链式配置文件路径 | Please provide chain config file path"
        return 1
    fi

    if [ ! -f "$chain_file" ]; then
        echo "❌ 链式配置文件不存在: $chain_file | Chain config file not found: $chain_file"
        return 1
    fi

    if ! command -v jq >/dev/null 2>&1; then
        echo "❌ 需要安装 jq 来解析配置文件 | jq is required to parse config file"
        echo "   安装命令 | Install command: brew install jq"
        return 1
    fi

    echo "📋 链式配置详情 | Chain Configuration Details: $chain_file"
    echo ""

    local config_data
    config_data=$(cat "$chain_file" 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "❌ 无法读取配置文件 | Unable to read config file"
        return 1
    fi

    # 验证并解析链式配置
    if ! _validate_chain_config "$config_data"; then
        return 1
    fi

    local parsed_chain_result
    if ! _parse_chain_config "$config_data" "parsed_chain_result"; then
        echo "❌ 链式配置解析失败 | Chain config parsing failed"
        return 1
    fi

    # 显示链式配置的详细信息
    local node_count
    node_count=$(echo "$parsed_chain_result" | jq '.node_count')
    echo "🔗 链式配置包含 $node_count 个节点 | Chain config contains $node_count nodes"
    echo ""

    for ((i=0; i<node_count; i++)); do
        local node_data node_type node_name
        node_data=$(echo "$parsed_chain_result" | jq ".nodes[$i]")
        node_type=$(echo "$node_data" | jq -r '.type')
        node_name=$(echo "$node_data" | jq -r '.name')

        echo "  🔸 节点 $((i+1)): $node_name (类型: $node_type) | Node $((i+1)): $node_name (type: $node_type)"

        if [ "$node_type" = "package" ]; then
            local package_dir package_name build_command
            package_dir=$(echo "$node_data" | jq -r '.package_dir')
            package_name=$(echo "$node_data" | jq -r '.package_name')
            build_command=$(echo "$node_data" | jq -r '.build_command')

            echo "    📦 包目录: $package_dir | Package directory: $package_dir"
            echo "    📦 包名称: $package_name | Package name: $package_name"
            echo "    🏗️  构建命令: $build_command | Build command: $build_command"
        elif [ "$node_type" = "app" ]; then
            local app_dir start_command
            app_dir=$(echo "$node_data" | jq -r '.app_dir')
            start_command=$(echo "$node_data" | jq -r '.start_command')

            echo "    🏗️  应用目录: $app_dir | App directory: $app_dir"
            echo "    🚀 启动命令: $start_command | Start command: $start_command"
        fi

        # 显示依赖关系
        local dependencies
        dependencies=$(echo "$node_data" | jq -r '.dependencies[]?' 2>/dev/null)
        if [ -n "$dependencies" ]; then
            echo "    🔗 依赖: $(echo "$dependencies" | tr '\n' ', ' | sed 's/,$//' | sed 's/,/, /g') | Dependencies: $(echo "$dependencies" | tr '\n' ', ' | sed 's/,$//' | sed 's/,/, /g')"
        fi
        echo ""
    done
}

# 验证链式配置文件 | Validate chain configuration file
_devup_validate_chain_config() {
    local chain_file="$1"

    if [ -z "$chain_file" ]; then
        echo "❌ 请提供链式配置文件路径 | Please provide chain config file path"
        return 1
    fi

    if [ ! -f "$chain_file" ]; then
        echo "❌ 链式配置文件不存在: $chain_file | Chain config file not found: $chain_file"
        return 1
    fi

    if ! command -v jq >/dev/null 2>&1; then
        echo "❌ 需要安装 jq 来解析配置文件 | jq is required to parse config file"
        echo "   安装命令 | Install command: brew install jq"
        return 1
    fi

    echo "🔍 验证链式配置文件: $chain_file | Validating chain config file: $chain_file"
    echo ""

    local config_data
    config_data=$(cat "$chain_file" 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "❌ 无法读取配置文件 | Unable to read config file"
        return 1
    fi

    # 验证 JSON 格式
    if ! echo "$config_data" | jq . >/dev/null 2>&1; then
        echo "❌ 配置文件不是有效的 JSON 格式 | Config file is not valid JSON"
        return 1
    fi

    # 验证链式配置格式
    if ! _validate_chain_config "$config_data"; then
        return 1
    fi

    # 尝试解析配置
    local parsed_chain_result
    if ! _parse_chain_config "$config_data" "parsed_chain_result"; then
        echo "❌ 链式配置解析失败 | Chain config parsing failed"
        return 1
    fi

    local node_count
    node_count=$(echo "$parsed_chain_result" | jq '.node_count')

    echo "✅ 配置文件验证成功！| Config file validation successful!"
    echo "📊 包含 $node_count 个有效节点 | Contains $node_count valid nodes"

    return 0
}

# 使用独立链式配置文件运行 | Run with standalone chain config file
_devup_run_with_chain_file() {
    local chain_file="$1"

    if [ -z "$chain_file" ]; then
        echo "❌ 请提供链式配置文件路径 | Please provide chain config file path"
        return 1
    fi

    if [ ! -f "$chain_file" ]; then
        echo "❌ 链式配置文件不存在: $chain_file | Chain config file not found: $chain_file"
        return 1
    fi

    if ! command -v jq >/dev/null 2>&1; then
        echo "❌ 需要安装 jq 来解析配置文件 | jq is required to parse config file"
        echo "   安装命令 | Install command: brew install jq"
        return 1
    fi

    echo "🔗 使用独立链式配置文件: $chain_file | Using standalone chain config file: $chain_file"
    echo ""

    local config_data
    config_data=$(cat "$chain_file" 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "❌ 无法读取配置文件 | Unable to read config file"
        return 1
    fi

    # 验证并解析链式配置
    if ! _validate_chain_config "$config_data"; then
        return 1
    fi

    local parsed_chain_result
    if ! _parse_chain_config "$config_data" "parsed_chain_result"; then
        echo "❌ 链式配置解析失败 | Chain config parsing failed"
        return 1
    fi

    echo "🚀 开始执行链式构建... | Starting chain build execution..."
    echo ""

    # TODO: 在这里实现链式配置的实际执行逻辑
    # 这里应该调用链式构建协调器来执行实际的构建流程
    echo "⚠️  链式构建执行逻辑尚未实现 | Chain build execution logic not yet implemented"
    echo "💡 请查看解析结果: | Please check parsed result:"
    echo "$parsed_chain_result" | jq '.'

    return 0
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
