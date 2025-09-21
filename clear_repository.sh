#!/bin/bash

# 清空GitHub仓库脚本
# 目标仓库: https://github.com/hanxiaochi/CICD-pate.git

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== GitHub仓库清空脚本 ===${NC}"
echo -e "${YELLOW}目标仓库: https://github.com/hanxiaochi/CICD-pate.git${NC}"
echo ""

# 确认操作
read -p "这将完全清空仓库历史，是否继续？(y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}操作已取消${NC}"
    exit 1
fi

# 检查是否已有远程仓库配置
if git remote get-url origin &>/dev/null; then
    current_origin=$(git remote get-url origin)
    echo -e "${YELLOW}当前远程仓库: $current_origin${NC}"
    
    # 确认是否更换远程仓库
    read -p "是否要更换为新仓库 CICD-pate？(y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git remote set-url origin https://github.com/hanxiaochi/CICD-pate.git
        echo -e "${GREEN}已更新远程仓库地址${NC}"
    fi
else
    # 添加远程仓库
    git remote add origin https://github.com/hanxiaochi/CICD-pate.git
    echo -e "${GREEN}已添加远程仓库${NC}"
fi

echo ""
echo -e "${YELLOW}开始清空仓库...${NC}"

# 方法一：创建新的孤立分支（推荐）
echo -e "${GREEN}步骤1: 创建新的孤立分支${NC}"
git checkout --orphan new-main

# 清除所有文件
echo -e "${GREEN}步骤2: 清除所有现有文件${NC}"
git rm -rf . 2>/dev/null || true

# 创建初始的空提交
echo -e "${GREEN}步骤3: 创建初始空提交${NC}"
echo "# CICD自动化部署系统" > README.md
echo "" >> README.md
echo "此仓库已重新初始化，历史记录已清空。" >> README.md
echo "" >> README.md
echo "## 说明" >> README.md
echo "- 仓库地址: https://github.com/hanxiaochi/CICD-pate.git" >> README.md
echo "- 创建时间: $(date)" >> README.md

git add README.md
git commit -m "Initial commit - 重新初始化仓库"

# 删除旧分支并重命名新分支
echo -e "${GREEN}步骤4: 重命名分支为main${NC}"
git branch -D main 2>/dev/null || true
git branch -m main

echo ""
echo -e "${YELLOW}准备推送到远程仓库...${NC}"
echo -e "${RED}警告: 这将强制覆盖远程仓库的所有内容！${NC}"
read -p "确认要强制推送吗？(y/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}步骤5: 强制推送到远程仓库${NC}"
    git push -f origin main
    
    echo ""
    echo -e "${GREEN}✅ 仓库清空完成！${NC}"
    echo -e "${GREEN}仓库地址: https://github.com/hanxiaochi/CICD-pate.git${NC}"
    echo ""
    echo -e "${YELLOW}接下来你可以：${NC}"
    echo "1. 添加新的文件到仓库"
    echo "2. 提交并推送新内容"
    echo "3. 仓库现在有一个干净的历史记录"
else
    echo -e "${YELLOW}未推送到远程仓库，本地更改已完成${NC}"
    echo "如需推送，请手动执行: git push -f origin main"
fi

echo ""
echo -e "${GREEN}脚本执行完毕${NC}"