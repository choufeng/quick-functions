#!/usr/bin/env bash
# Quick Functions 测试脚本 | Quick Functions Test Script

echo "🧪 Quick Functions 测试 | Quick Functions Test"
echo ""

# 检查函数文件是否存在
if [ -f "functions/devup-functions.sh" ]; then
    echo "✅ 函数文件存在 | Function file exists"
else
    echo "❌ 函数文件不存在 | Function file not found"
    exit 1
fi

# 临时加载函数进行测试
source functions/devup-functions.sh

# 测试 devup_config 函数
echo ""
echo "📋 测试配置助手 | Testing configuration helper:"
devup_config

echo ""
echo "🎯 测试完成 | Test completed"

# 显示使用提示
echo ""
echo "💡 使用提示 | Usage Tips:"
echo "1. 运行 ./install.sh 进行安装 | Run ./install.sh to install"
echo "2. 根据需要调整配置 | Adjust configuration as needed"
echo "3. 运行 devup 开始使用 | Run devup to start using"
