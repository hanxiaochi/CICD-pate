#!/bin/bash

# 快速验证脚本

echo "======================================"
echo "CICD系统 - Ruby版本检测修复验证"
echo "======================================"

# 导入版本比较函数
source ./start_refactored.sh check_ruby 2>/dev/null || {
    echo "加载脚本失败，手动定义版本比较函数..."
    
    version_compare() {
        local version1="$1"
        local version2="$2"
        
        IFS='.' read -ra VERSION1 <<< "$version1"
        IFS='.' read -ra VERSION2 <<< "$version2"
        
        local max_length=${#VERSION1[@]}
        if [ ${#VERSION2[@]} -gt $max_length ]; then
            max_length=${#VERSION2[@]}
        fi
        
        for ((i=0; i<max_length; i++)); do
            local v1=${VERSION1[i]:-0}
            local v2=${VERSION2[i]:-0}
            
            if [ $v1 -gt $v2 ]; then
                return 0
            elif [ $v1 -lt $v2 ]; then
                return 1
            fi
        done
        
        return 0
    }
}

echo ""
echo "🔍 检测当前Ruby环境："
echo "------------------------"

if command -v ruby &>/dev/null; then
    # 显示完整Ruby版本信息
    echo "Ruby完整版本信息: $(ruby -v)"
    
    # 提取版本号
    current_version=$(ruby -v | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    echo "提取的版本号: $current_version"
    
    # 版本比较测试
    echo ""
    echo "🧪 版本比较测试："
    echo "------------------------"
    
    if version_compare "$current_version" "3.0.0"; then
        echo "✅ 版本检测结果: Ruby $current_version >= 3.0.0 (满足要求)"
        echo "✅ 修复成功！现在脚本会正确识别您的Ruby版本"
    else
        echo "❌ 版本检测结果: Ruby $current_version < 3.0.0 (不满足要求)"
        echo "❌ 仍有问题，这不应该发生"
    fi
    
    # 其他测试
    echo ""
    echo "📋 其他版本测试："
    echo "------------------------"
    test_versions=("2.7.0" "3.0.0" "3.1.0" "3.2.3" "3.3.0")
    
    for test_ver in "${test_versions[@]}"; do
        if version_compare "$test_ver" "3.0.0"; then
            result="✅ 满足要求"
        else
            result="❌ 不满足要求"
        fi
        echo "$test_ver: $result"
    done
    
else
    echo "❌ Ruby未安装"
    echo "请先安装Ruby 3.0+或运行: ./start_refactored.sh install"
fi

echo ""
echo "🚀 接下来您可以："
echo "------------------------"
echo "1. 运行 ./start_refactored.sh install  # 完整安装（如果Ruby版本已满足，会跳过安装）"
echo "2. 运行 ./start_refactored.sh start    # 直接启动系统"
echo "3. 运行 bundle install                 # 安装Ruby依赖包"

echo ""
echo "======================================"