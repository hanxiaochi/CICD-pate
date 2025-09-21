#!/bin/bash

# 测试版本比较功能

# 版本比较函数
version_compare() {
    local version1="$1"
    local version2="$2"
    
    # 将版本号拆分为数组
    IFS='.' read -ra VERSION1 <<< "$version1"
    IFS='.' read -ra VERSION2 <<< "$version2"
    
    # 找到最大长度
    local max_length=${#VERSION1[@]}
    if [ ${#VERSION2[@]} -gt $max_length ]; then
        max_length=${#VERSION2[@]}
    fi
    
    # 逐位比较
    for ((i=0; i<max_length; i++)); do
        local v1=${VERSION1[i]:-0}
        local v2=${VERSION2[i]:-0}
        
        if [ $v1 -gt $v2 ]; then
            return 0  # version1 > version2
        elif [ $v1 -lt $v2 ]; then
            return 1  # version1 < version2
        fi
    done
    
    return 0  # 版本相等，返回0（满足要求）
}

echo "测试Ruby版本比较功能"
echo "====================="

# 测试用例
test_cases=(
    "3.2.3 >= 3.0.0"
    "3.1.0 >= 3.0.0"
    "3.0.0 >= 3.0.0"
    "2.7.0 >= 3.0.0"
    "3.2.3 >= 2.7.0"
)

for test_case in "${test_cases[@]}"; do
    read -r version1 op version2 <<< "$test_case"
    
    if version_compare "$version1" "$version2"; then
        result="✅ PASS"
    else
        result="❌ FAIL"
    fi
    
    echo "$test_case: $result"
done

echo ""
echo "当前Ruby版本检测："
if command -v ruby &>/dev/null; then
    current_version=$(ruby -v | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    echo "检测到Ruby版本: $current_version"
    
    if version_compare "$current_version" "3.0.0"; then
        echo "✅ 版本满足要求 (>= 3.0.0)"
    else
        echo "❌ 版本不满足要求 (< 3.0.0)"
    fi
else
    echo "❌ Ruby未安装"
fi