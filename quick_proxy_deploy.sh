#!/bin/bash

# CICD系统 - 代理加速快速部署脚本
# 使用代理地址实现快速克隆和部署
# =====================================

echo "🚀 CICD系统代理加速部署"
echo "======================"

# 使用代理地址
PROXY_REPO_URL="https://xget.xi-xu.me/gh/hanxiaochi/CICD-pate.git"
DEPLOY_DIR="$HOME/CICD-pate"

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}📡 使用代理地址加速下载：${NC}"
echo -e "${YELLOW}$PROXY_REPO_URL${NC}"

# 清理旧目录
if [ -d "$DEPLOY_DIR" ]; then
    echo -e "${YELLOW}⚠️  删除现有目录...${NC}"
    rm -rf "$DEPLOY_DIR"
fi

# 克隆代码
echo -e "${BLUE}📦 克隆最新代码...${NC}"
git clone "$PROXY_REPO_URL" "$DEPLOY_DIR"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ 代码克隆成功${NC}"
    cd "$DEPLOY_DIR"
    
    # 给脚本执行权限
    chmod +x *.sh
    
    echo -e "\n${GREEN}🎯 可用的快速命令：${NC}"
    echo "================================"
    echo "进入目录: cd $DEPLOY_DIR"
    echo "一键清理: ./cloud_cleanup.sh --force"
    echo "一键部署: ./cloud_deploy.sh"  
    echo "一键验证: ./cloud_verify.sh"
    echo "完整流程: ./cloud_test_workflow.sh full"
    echo ""
    echo -e "${BLUE}📋 或者使用交互式菜单：${NC}"
    echo "./cloud_test_workflow.sh"
    
    # 询问是否立即部署
    echo ""
    read -p "是否立即开始部署？(y/n): " choice
    if [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then
        echo -e "\n${GREEN}🚀 开始自动部署...${NC}"
        ./cloud_deploy.sh
    else
        echo -e "\n${YELLOW}💡 稍后可手动执行部署命令${NC}"
    fi
    
else
    echo -e "${RED}❌ 代码克隆失败${NC}"
    echo "请检查网络连接或代理地址是否可用"
    exit 1
fi