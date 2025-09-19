#!/bin/bash

# Stream C API 测试脚本 | Stream C API Test Script
# 测试新的 _devup_load_config API 功能 | Test new _devup_load_config API functionality

# 加载函数文件 | Load function file
source "./functions/devup-functions.sh"

# 设置测试配置文件路径 | Set test config file path
export HOME_CONFIG="$HOME/.quick-functions/devup-configs.json"
export TEST_CONFIG="./test-config.json"

echo "🧪 开始 Stream C API 测试 | Starting Stream C API Tests"
echo "=========================================="

# 函数：复制测试配置 | Function: Copy test config
setup_test_config() {
    mkdir -p "$HOME/.quick-functions"
    cp "$TEST_CONFIG" "$HOME_CONFIG"
    echo "✅ 测试配置已设置 | Test config set up"
}

# 函数：清理测试配置 | Function: Clean up test config
cleanup_test_config() {
    rm -f "$HOME_CONFIG"
    echo "🧹 测试配置已清理 | Test config cleaned up"
}

# 测试1：传统单包模式 | Test 1: Legacy single package mode
test_legacy_mode() {
    echo ""
    echo "📦 测试1：传统单包模式 | Test 1: Legacy single package mode"
    echo "----------------------------------------"
    
    local pkg_dir app_dir pkg_name start_cmd build_cmd config_type chain_result
    
    if _devup_load_config "legacy-test" pkg_dir app_dir pkg_name start_cmd build_cmd chain_result config_type; then
        echo "✅ 传统模式加载成功 | Legacy mode loaded successfully"
        echo "   配置类型: $config_type | Config type: $config_type"
        echo "   包目录: $pkg_dir | Package dir: $pkg_dir"
        echo "   应用目录: $app_dir | App dir: $app_dir"
        echo "   包名称: $pkg_name | Package name: $pkg_name"
        echo "   链式结果: ${chain_result:-'空/Empty'} | Chain result: ${chain_result:-'Empty'}"
        return 0
    else
        echo "❌ 传统模式加载失败 | Legacy mode load failed"
        return 1
    fi
}

# 测试2：链式配置模式 | Test 2: Chain configuration mode
test_chain_mode() {
    echo ""
    echo "🔗 测试2：链式配置模式 | Test 2: Chain configuration mode"
    echo "----------------------------------------"
    
    local pkg_dir app_dir pkg_name start_cmd build_cmd config_type chain_result
    
    if _devup_load_config "chain-test" pkg_dir app_dir pkg_name start_cmd build_cmd chain_result config_type; then
        echo "✅ 链式模式加载成功 | Chain mode loaded successfully"
        echo "   配置类型: $config_type | Config type: $config_type"
        echo "   主要包目录: $pkg_dir | Primary package dir: $pkg_dir"
        echo "   主要包名称: $pkg_name | Primary package name: $pkg_name"
        
        if [ -n "$chain_result" ]; then
            echo "   链式配置节点数: $(echo "$chain_result" | jq '.node_count') | Chain config node count: $(echo "$chain_result" | jq '.node_count')"
            echo "   所有节点名称: $(echo "$chain_result" | jq -r '.nodes[].name' | tr '\n' ', ' | sed 's/,$//')"
        else
            echo "   ⚠️  链式结果为空 | Chain result is empty"
        fi
        return 0
    else
        echo "❌ 链式模式加载失败 | Chain mode load failed"
        return 1
    fi
}

# 测试3：向后兼容性 | Test 3: Backward compatibility
test_backward_compatibility() {
    echo ""
    echo "🔄 测试3：向后兼容性 | Test 3: Backward compatibility"
    echo "----------------------------------------"
    
    local pkg_dir app_dir pkg_name start_cmd build_cmd
    
    # 使用旧的API调用方式 | Using old API call style
    if _devup_load_config "legacy-test" pkg_dir app_dir pkg_name start_cmd build_cmd; then
        echo "✅ 向后兼容性测试成功 | Backward compatibility test successful"
        echo "   包目录: $pkg_dir | Package dir: $pkg_dir"
        echo "   包名称: $pkg_name | Package name: $pkg_name"
        return 0
    else
        echo "❌ 向后兼容性测试失败 | Backward compatibility test failed"
        return 1
    fi
}

# 测试4：错误处理 | Test 4: Error handling
test_error_handling() {
    echo ""
    echo "⚠️  测试4：错误处理 | Test 4: Error handling"
    echo "----------------------------------------"
    
    local pkg_dir app_dir pkg_name start_cmd build_cmd config_type chain_result
    
    # 测试不存在的配置 | Test non-existent config
    if _devup_load_config "non-existent-config" pkg_dir app_dir pkg_name start_cmd build_cmd chain_result config_type; then
        echo "❌ 应该失败但成功了 | Should have failed but succeeded"
        return 1
    else
        echo "✅ 错误处理正常：正确拒绝不存在的配置 | Error handling works: correctly rejected non-existent config"
        return 0
    fi
}

# 运行所有测试 | Run all tests
main() {
    local test_results=()
    
    setup_test_config
    
    echo ""
    echo "🚀 开始执行测试用例 | Starting test cases execution"
    
    # 执行测试 | Execute tests
    test_legacy_mode && test_results+=("✅ Test1") || test_results+=("❌ Test1")
    test_chain_mode && test_results+=("✅ Test2") || test_results+=("❌ Test2") 
    test_backward_compatibility && test_results+=("✅ Test3") || test_results+=("❌ Test3")
    test_error_handling && test_results+=("✅ Test4") || test_results+=("❌ Test4")
    
    cleanup_test_config
    
    # 输出测试结果 | Output test results
    echo ""
    echo "📊 测试结果总结 | Test Results Summary"
    echo "=========================================="
    for result in "${test_results[@]}"; do
        echo "  $result"
    done
    
    # 检查是否所有测试都通过 | Check if all tests passed
    if [[ " ${test_results[@]} " =~ " ❌ " ]]; then
        echo ""
        echo "❌ 部分测试失败 | Some tests failed"
        return 1
    else
        echo ""
        echo "✅ 所有测试通过！ | All tests passed!"
        return 0
    fi
}

# 执行主函数 | Execute main function
main "$@"