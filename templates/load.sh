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
