#!/bin/bash
# Git推送重试脚本

echo "=== Git推送重试脚本 ==="
echo "目标仓库: https://github.com/hanxiaochi/CICD-pate.git"
echo

# 检查网络连接
echo "1. 检查网络连接..."
ping -c 1 github.com > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✓ 网络连接正常"
else
    echo "✗ 网络连接异常，请检查网络设置"
    exit 1
fi

# 检查Git状态
echo "2. 检查Git状态..."
git status --porcelain
if [ $? -eq 0 ]; then
    echo "✓ Git仓库状态正常"
else
    echo "✗ Git仓库状态异常"
    exit 1
fi

# 显示待推送的提交
echo "3. 待推送的提交："
git log origin/master..HEAD --oneline

# 多次尝试推送
echo "4. 开始推送..."
for i in {1..5}; do
    echo "尝试推送 (第 $i 次)..."
    
    if git push origin master; then
        echo "✓ 推送成功！"
        echo "提交已推送到: https://github.com/hanxiaochi/CICD-pate.git"
        exit 0
    else
        echo "✗ 推送失败，等待 5 秒后重试..."
        sleep 5
    fi
done

echo "✗ 推送失败，已尝试 5 次"
echo "请稍后手动执行: git push origin master"
exit 1